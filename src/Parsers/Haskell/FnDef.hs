module Parsers.Haskell.FnDef where

import Lexers.Haskell.Layout     (lexeme)
import Parsers.Haskell.Common    (literal, nonTokenQVar, qCtor, qCtorOp, qVar,
                                  qVarOp, token, var, varOp)
import Parsers.Haskell.Pattern   (pattern')
import Parsers.Haskell.Type      (type')
import SyntaxTrees.Haskell.FnDef (Associativity (LAssoc, RAssoc),
                                  CaseBinding (..), DoStep (..), FnBody (..),
                                  FnDef (FnDef), FnDefOrSig (..), FnOp (..),
                                  FnSig (..), FnVar (..), Guard (..),
                                  GuardedFnBody (..),
                                  InfixFnAnnotation (InfixFnAnnotation),
                                  MaybeGuardedFnBody (..), PatternGuard (..))

import Bookhound.Parser              (Parser, andThen, check, withError)
import Bookhound.ParserCombinators   (IsMatch (is), sepByOps, someSepBy, (->>-),
                                      (<|>), (|*), (|+), (|?))
import Bookhound.Parsers.Char        (comma, dot)
import Bookhound.Parsers.Collections (listOf, tupleOf)
import Bookhound.Parsers.Number      (int)
import Bookhound.Parsers.String      (spacing, string, withinCurlyBrackets,
                                      withinParens, withinSquareBrackets)

import Data.Foldable (Foldable (fold))
import Data.Maybe    (maybeToList)
import Utils.String  (wrapCurly)


fnSig :: Parser FnSig
fnSig = withError "Function signature" $
  FnSig <$> (var <* is "::")
        <*> type'


fnDef :: Parser FnDef
fnDef = withError "Function definition" $
  FnDef <$> (tupleOf var <|> pure <$> var)
        <*> (pattern' |*)
        <*> maybeGuardedFnBody (is "=")


infixAnnotation :: Parser InfixFnAnnotation
infixAnnotation = withError "Infix annotation" $
  InfixFnAnnotation <$> token (LAssoc <$ is "infixl" <|>
                               RAssoc <$ is "infixr")
                    <*> token int
                    <*> varOp


fnDefOrSig :: Parser FnDefOrSig
fnDefOrSig =  Def <$> fnDef <|>
              Sig <$> fnSig

fnBody :: Parser FnBody
fnBody = topLevelFnApply <|> openForm

  where
    topLevelFnApply = FnApply <$> delimitedForm
                              <*> (pure <$> lambdaExpr)

    fnApply = FnApply <$> delimitedForm
                      <*> (delimitedForm |+)

    infixFnApply = uncurry InfixFnApply <$>
      sepByOps fnOp (infixArgForm <|> withinParens typeAnnotation)

    leftOpSection = uncurry LeftOpSection
      <$> withinParens ((,) <$> fnOp <*> openForm)

    rightOpSection = uncurry RightOpSection
      <$> withinParens ((,) <$> openForm <*> fnOp)

    opSection = leftOpSection <|> rightOpSection


    lambdaExpr = LambdaExpr <$> (is '\\' *> (pattern' |*))
                            <*> (is "->" *> openForm)

    letExpr = LetExpr <$> (is "let" *> withinContext fnDefOrSig)
                      <*> (is "in"  *> openForm)

    whereExpr = WhereExpr <$> withinCurlyBrackets openForm <* is "where"
                          <*> withinContext fnDefOrSig

    ifExpr = IfExpr <$> (is "if"   *> openForm)
                    <*> (is "then" *> openForm)
                    <*> (is "else" *> openForm)

    multiWayIfExpr = MultiWayIfExpr <$>
      (is "if" *> (withinContext $ guardedFnBody $ is "->"))

    doExpr = DoExpr <$> (is "do" *> withinContext doStep)

    caseOfExpr = CaseOfExpr <$> (is "case" *> openForm <* is "of")
                            <*> withinContext caseBinding

    lambdaCaseExpr = LambdaCaseExpr <$> (is "\\case" *> withinContext caseBinding)

    listRange = withinSquareBrackets $
      ListRange <$> (openForm <* is "..")
                <*> (openForm |?)

    typeAnnotation = TypeAnnotation <$> (infixArgForm <* is "::")
                                    <*> type'

    tuple = Tuple <$> tupleOf openForm

    list = List <$> listOf openForm

    fnOp = CtorOp' <$> qCtorOp
       <|> VarOp' <$> qVarOp

    fnOp' = FnOp' <$> withinParens fnOp

    fnVar = FnVar' . Selector <$> withinParens (dot *> var)
        <|> FnVar' <$>
            (Selection <$> nonTokenQVar <* dot <*> someSepBy dot var)
        <|> FnVar' . Var' <$> qVar
        <|> FnVar' . Ctor' <$> qCtor

    literal' = Literal' <$> literal

    recordCreate = RecordCreate <$> qCtor <*> recordFields

    recordUpdate = RecordUpdate <$> delimitedForm <*> recordFields

    recordFields = withinCurlyBrackets (someSepBy comma recordField)

    recordField  = (,) <$> var <*> (is "=" *> openForm)

    infixArgForm = complexInfixForm <|> withinParens complexInfixForm
               <|> singleForm

    openForm = complexForm <|> singleForm
               <|> withinParens (complexForm <|> singleForm)

    delimitedForm = singleForm <|> withinParens complexForm
                    <|> withinParens singleForm

    singleForm = fnOp' <|> fnVar <|> literal' <|> tuple <|>
                 listRange <|> list <|> opSection

    complexForm = infixFnApply <|> complexInfixForm <|> typeAnnotation


    complexInfixForm = fnApply <|> lambdaCaseExpr <|>
                       lambdaExpr <|> letExpr <|> whereExpr <|>
                       ifExpr <|> multiWayIfExpr <|> doExpr <|>
                       caseOfExpr <|> withinParens infixFnApply <|>
                       recordCreate <|> recordUpdate


doStep :: Parser DoStep
doStep = DoBinding  <$> (tupleOf var <|> pure <$> var) <* is "<-"
                    <*> (adaptFnBody `andThen` fnBody) <|>
         LetBinding <$> (is "let" *> withinContext fnDefOrSig) <|>
         Body       <$> (adaptFnBody `andThen` fnBody)


caseBinding :: Parser CaseBinding
caseBinding = CaseBinding <$> pattern' <*> maybeGuardedFnBody (is "->")


maybeGuardedFnBody :: Parser a -> Parser MaybeGuardedFnBody
maybeGuardedFnBody sep = Guarded  <$> (guardedFnBody sep |+) <|>
                         Standard <$> (sep *> (adaptFnBody `andThen` fnBody))

guardedFnBody :: Parser a -> Parser GuardedFnBody
guardedFnBody sep = GuardedFnBody <$> guard <* sep <*> (adaptFnBody `andThen` fnBody)

guard :: Parser Guard
guard = Otherwise <$  (is "|" *> token (is "otherwise")) <|>
        Guard     <$> (is "|" *> someSepBy comma patternGuard)


patternGuard :: Parser PatternGuard
patternGuard = PatternGuard <$> (pattern' <* is "<-") <*> fnBody <|>
               SimpleGuard  <$> fnBody


adaptFnBody :: Parser String
adaptFnBody = do start <- otherText
                 next <- ((is "where" ->>- string) |?)
                 other <- ((is ";" ->>- string) |?)
                 let x = maybe start ((wrapCurly start) ++) next ++ fold other
                 pure x
 where
   otherText = (spacing |?) ->>- (textElem |*)
   textElem = check "" (`notElem` ["where", ";"]) lexeme ->>- (spacing |?)


statements :: Parser a -> Parser [a]
statements parser = fold <$> someSepBy (is ";") (maybeToList <$> (parser |?))

withinContext :: Parser a -> Parser [a]
withinContext = withinCurlyBrackets . statements

withinContextTupled :: Parser a1 -> Parser a2 -> Parser ([a1], [a2])
withinContextTupled p1 p2 = withinCurlyBrackets $
                             (,) <$> statements p1 <*> statements p2
