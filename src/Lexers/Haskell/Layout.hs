module Lexers.Haskell.Layout where


import Parser            (ParseError, Parser, check, runParser)
import ParserCombinators (IsMatch (is, isNot, noneOf, oneOf), (<|>), (>>>),
                          (|*), (|+), (|?))
import Parsers.Char      (char, space)

import Control.Monad (foldM)
import Data.Foldable (Foldable (fold))

import Data.Monoid.HT (when)

import Data.Maybe     (fromMaybe)
import Parsers.String (spacing, withinDoubleQuotes, withinParens, withinQuotes,
                       word)
import Utils.Foldable (hasNone, hasSome)
import Utils.List     (safeHead, safeTail)
import Utils.String   (joinWords, wrapCurly, wrapDoubleQuotes, wrapParens,
                       wrapQuotes)



adaptLayout :: String -> Either ParseError String
adaptLayout str = (++ " }") . unlines . fst4 <$> layoutLines
  where
    layoutLines = foldM layout args . (++ pure "") . filter (/= "") =<< input
    input = lines . fold <$> runParser parensLayout str
    args = ([], [], False, False)


layout :: ([String], [Int], Bool, Bool) -> String -> Either ParseError ([String], [Int], Bool, Bool)
layout (x, y, z, t) str = runParser layoutParser str
  where
    layoutParser =
      do spaces' <- (space |*)
         start <- otherText
         layoutText <- (layoutBegin |?)
         spaces'' <- (space |*)
         rest <- otherText
         let hasCurly = fromMaybe False $ (== '{')  <$> safeHead rest
         let indents = when z [length spaces'] ++ y
         let layoutNextLine = hasSome layoutText && hasNone rest
         let contextIndent = length $ spaces' ++ start ++ fold layoutText ++ spaces''
         let (newIndents, beginSep, stop) = calcIndent indents (length spaces')
                                                               (t || hasCurly)
         let endSep = when (hasSome layoutText && not hasCurly) " {"
         let indents' = when (hasSome layoutText && hasSome rest)
                        [contextIndent] ++ newIndents
         let text = x ++ [spaces' ++ beginSep ++ start ++ fold layoutText ++
                          endSep ++  spaces'' ++ rest]
         pure $ (text, indents', layoutNextLine, stop)


parensLayout :: Parser [String]
parensLayout = (((spacing |?) >>>
                 elem' <|> parensParser <|>
                (wrapParens . fold <$> withinParens parensLayout) >>>
                (spacing |?)) |*)
  where
    elem' = lexeme' id
    parensParser = wrapParens <$> withinParens
                ((spacing |?) >>> layoutBegin >>> spacing >>>
                 (wrapCurly . fold <$> parensLayout))



calcIndent :: [Int] -> Int -> Bool -> ([Int], String, Bool)
calcIndent indentLvls curr stop =
  (newIndentLvls, joinWords [closeContexts, sep], shouldStop)
  where
    extraElems = if (not stop) then extra else fold $ safeTail extra
    closeContexts = fold ("} " <$ extraElems)
    shouldStop = stop && hasNone closeContexts
    sep = when (any (== curr) (safeHead newIndentLvls)) "; "
    (extra, newIndentLvls) = span (curr <) indentLvls


layoutTokens :: [String]
layoutTokens = [("(" ++), id] <*> ["where", "let", "do", "of", "\\case"]

layoutBegin :: Parser String
layoutBegin = oneOf layoutTokens


otherText :: Parser String
otherText = fold <$>
           (((check "" (`notElem` layoutTokens) lexeme) >>> (space |*)) |*)


lexeme :: Parser String
lexeme = wrapDoubleQuotes  <$> withinDoubleQuotes (isNot '"'  |*)             <|>
         wrapQuotes . pure <$> withinQuotes (char <|> ((is '\\' |?) *> char)) <|>
         word



otherText' :: Parser String
otherText' = lexeme' (check "" (`notElem` layoutTokens))


lexeme' :: (Parser String -> Parser String) -> Parser String
lexeme' f = (spacing |?) >>> f parser >>> (spacing |?)
  where
    parser = wrapDoubleQuotes  <$> withinDoubleQuotes (isNot '"'  |*)             <|>
             wrapQuotes . pure <$> withinQuotes (char <|> ((is '\\' |?) *> char)) <|>
             word'

word' :: Parser String
word' = ((noneOf [' ', '\n', '\t', '(', ')']) |+)

fst4 :: (a, b, c, d) -> a
fst4 (x, _, _, _) = x
