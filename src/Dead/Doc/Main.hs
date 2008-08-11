{- |
    The Web interface, expects to be run as a CGI script.
    This does not require Haskell CGI etc, it just dumps HTML to the console
-}

module Doc.Main where

import General.CGI
import Data.Maybe
import Data.Char
import Data.List
import Numeric


main = do x <- cgiArgs
          let modu = lookup "module" x
              mode = lookup "mode" x

              name = case lookup "name" x of
                        Nothing -> ""
                        Just ('(':xs) -> init xs
                        Just x -> x
          
          page <- hoodoc mode modu name
          putStr $ "Location: " ++ page ++ "\n\n"


hoodoc :: Maybe String -> Maybe String -> String -> IO String

-- keywords are special
hoodoc (Just "keyword") _ name = return $ "http://www.haskell.org/haskellwiki/Keywords#" ++ concatMap f name
    where
        f x | isAlpha x || x `elem` "_-:" = [x]
            | otherwise = '.' : map toUpper (showHex (ord x) "")


-- if you have no name, just direct them straight at the module page
hoodoc _ (Just modu) "" = calcPage modu ""

-- haddock assigns different prefixes for each type
hoodoc (Just "func") (Just modu) name = calcPage modu ("#v%3A" ++ escape name)
hoodoc (Just _     ) (Just modu) name = calcPage modu ("#t%3A" ++ escape name)

hoodoc _ _ _ = return failPage


failPage = "nodocs.htm"
haddockPrefix = "http://haskell.org/ghc/docs/latest/html/libraries/"
wikiPrefix = "http://www.haskell.org/hawiki/LibraryDocumentation/"


calcPage :: String -> String -> IO String
calcPage modu suffix =
    do x <- readFile "res/documentation.txt"
       let xs = mapMaybe f $ lines x
       return $ case lookup modu xs of
           Just "wiki" -> wikiPrefix ++ modu ++ suffix
           Just a -> haddockLoc a ++ map g modu ++ ".html" ++ suffix
           Nothing -> failPage
    where
        f ys = case break (== '\t') ys of
                   (a, [] ) -> Nothing
                   (a, b) -> Just (a, dropWhile isSpace b)
        
        haddockLoc "gtk" = "http://haskell.org/gtk2hs/docs/gtk2hs-docs-0.9.10/"
        haddockLoc a = haddockPrefix ++ a ++ "/"
        
        g '.' = '-'
        g x   = x