module CommandLine.Options where

import Data.Either.Extra   (mapLeft)
import Data.List           (intercalate)
import Data.Text           (pack)
import Options.Applicative hiding ((<|>))

import qualified Bookhound.Parser            as Bookhound
import           Bookhound.ParserCombinators



opts :: Parser Opts
opts = Opts
    <$> parserOption language
        ( long "language"
        <> short 'l'
        <> help "Target language")
    <*> strOption
        ( long "input"
        <> short 'i'
        <> help "Path of input Haskell file or directory" )
    <*> strOption
        ( long "output"
        <> short 'o'
        <> help "Path of output file or directory" )
    <*> switch
        ( long "format"
        <> short 'f'
        <> help "Apply formatter on output file(s)" )
    <*> switch
        ( long "watch"
        <> short 'w'
        <> help "Watch for changes and convert automatically" )
    <*> switch
        ( long "clear"
        <> help "Clear the output directory contents before conversion" )

optsInfo :: ParserInfo Opts
optsInfo = info (helper <*> opts)
           ( fullDesc
           <> progDesc "Compile Haskell file(s) into a target language. \n"
           <> footer ("Supported languages: "
            <> (intercalate ", " $ show <$> ([minBound .. maxBound] :: [Language])))
           <> header "polyglot" )

data Opts
  = Opts
      { language      :: Language
      , sourcePath    :: FilePath
      , targetPath    :: FilePath
      , autoFormat    :: Bool
      , watchMode     :: Bool
      , clearContents :: Bool
      }

data Language
  = Purescript
  | Scala
  deriving (Bounded, Enum, Eq, Ord, Show)


language :: Bookhound.Parser Language
language = Purescript <$ oneOf ["Purescript", "purescript", "purs"] <|>
           Scala      <$ oneOf ["Scala", "scala"]



parserOption :: Bookhound.Parser a -> Options.Applicative.Mod Options.Applicative.OptionFields a -> Parser a
parserOption parser = option $ eitherReader $ reader
  where
    reader = mapLeft show . Bookhound.runParser parser . pack
