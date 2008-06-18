
module Hoogle.DataBase.Type(
    DataBase(..), createDataBase, showDataBase,
    locateWebDocs, searchName, searchType, getKinds
    ) where


import Hoogle.DataBase.Items
import Hoogle.DataBase.Modules
import Hoogle.DataBase.Texts
import Hoogle.DataBase.Kinds
import Hoogle.DataBase.Alias
import Hoogle.DataBase.Instances
import Hoogle.DataBase.Types
import Hoogle.DataBase.Reduce
import Hoogle.Item.All
import Hoogle.TypeSig.All
import Hoogle.Result.All

import Data.List
import Data.Binary.Defer
import General.All
import qualified Data.IntSet as IntSet


data DataBase = DataBase {
                    package :: String,
                    webdocs :: String,
                    
                    -- the static and cached information
                    items :: Items,
                    modules :: Modules,
                    texts :: Texts,
                    kinds :: Kinds,
                    alias :: Alias,
                    instances :: Instances,
                    types :: Types
                }
                deriving Show

instance BinaryDefer DataBase where
    bothDefer = defer [\ ~(DataBase a b c d e f g h i) ->
        unit DataBase << a << b <<~ c <<~ d <<~ e <<~ f <<~ g <<~ h <<~ i]


createDataBase :: [Item] -> DataBase
createDataBase items1 = DataBase "" "" newItems newModules
        (createTexts items) (createKinds items) (createAlias items)
        (createInstances items) (createTypes items)
    where
        -- these are the two things that change the items
        (items2,newModules) = createModules items1
        (items ,newItems  ) = createItems items2


sections = [("alias",show . alias)
           ,("types",show . types)
           ]

showDataBase :: String -> DataBase -> String
showDataBase sect db =
    case lookup sect sections of
        Just i -> i db
        Nothing -> "ERROR: do not know how to show section, " ++ show sect ++ "\n" ++
                   "Must be one of: " ++ unwords (map fst sections)


-- forward methods
searchName :: DataBase -> [String] -> [Result]
searchName db xs = map (resultText xs . getItem db) ans
    where
        res = map (IntSet.fromList . searchTexts (texts db)) xs
        ans = IntSet.toList $ IntSet.unions res


searchType :: DataBase -> TypeSig -> [Result]
searchType db t = [resultType m (getItem db i) | (i,m) <- searchTypes ts red t]
    where
        (ts,is,as) = (types db, instances db, alias db)
        red = reduce is as


getItem :: DataBase -> ItemId -> Item
getItem db i = item{itemMod = getModuleFromId (modules db) (modId $ itemMod item)}
    where item = getItemFromId (items db) i


getKinds :: DataBase -> String -> [Int]
getKinds x = getNameKinds (kinds x)



{-
mergeResults :: DataBase -> [String] -> [[Result ()]] -> IO [Result DataBase]
mergeResults database query xs = merge (map (sortBy cmp) xs)
    where
        getId = fromJust . itemId . itemResult
        cmp a b = getId a `compare` getId b

        merge xs | null tops = return []
                 | otherwise = do
                 result <- loadResult $ setResultDataBase database $ snd $ head nows
                 let tm = computeTextMatch
                                    (fromJust $ itemName $ itemResult result)
                                    [(q, head $ textMatch $ fromJust $ textResult x) | (q,x) <- nows]
                     result2 = result{textResult = Just tm}
                 ans <- merge rest
                 return (result2:ans)
            where
                nows = [(q,x) | (q,x:_) <- zip query xs, getId x == now]
                rest = [if not (null x) && getId (head x) == now then tail x else x | x <- xs]
                now = minimum $ map getId tops
                tops = [head x | x <- xs, not $ null x]


-- fill in the global methods of TextMatch
-- given a list of TextMatchOne
fixupTextMatch :: String -> Result a -> Result a
fixupTextMatch query result = result{textResult = Just newTextResult}
    where
        name = fromJust $ itemName $ itemResult result
        matches = textMatch $ fromJust $ textResult result
        newTextResult = computeTextMatch name [(query,head matches)]
-}


locateWebDocs :: DataBase -> Item -> Maybe String
locateWebDocs db item
    | null url = Nothing
    | isItemModule $ itemRest item = Just $ url ++ modu ++ ['-'|not $ null modu] ++ itemName item ++ ".html"
    | otherwise = Just $ url ++ modu ++ ".html#" ++ code ++ nam
    where
        nam = escape $ itemName item
        modu = concat $ intersperse "-" $ modName $ itemMod item
        url = webdocs db
        
        code = case itemRest item of
                    ItemFunc{} -> "v%3A"
                    _ -> "t%3A"