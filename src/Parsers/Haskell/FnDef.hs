module Parsers.Haskell.FnDef where

import Parser
import ParserCombinators
import Parsers.Char
import Parsers.Collections (listOf, tupleOf)
import Parsers.Haskell.Common
import Parsers.Haskell.Pattern
import Parsers.Haskell.Type
import Parsers.String
import SyntaxTrees.Haskell.FnDef

fnSig :: Parser FnSig
fnSig = FnSig <$> (var <* is "::") <*> type'

fnDef :: Parser FnDef
fnDef = FnDef <$> var <*> (pattern' |*) <*> maybeGuardedFnBody (is "=")

fnDefOrSig :: Parser FnDefOrSig
fnDefOrSig =
  Def <$> fnDef
    <|> Sig <$> fnSig

fnBody :: Parser FnBody
fnBody = openForm
  where
    fnApply = FnApply <$> delimitedForm <*> (delimitedForm |+)

    infixFnApply = uncurry InfixFnApply <$> sepByOp fnOp (complexInfixForm <|> singleForm)

    lambdaExpr =
      LambdaExpr <$> (is '\\' *> someSepBy comma var)
        <*> (is "->" *> openForm)

    letExpr =
      LetExpr <$> (is "let" *> withinContext fnDefOrSig)
        <*> (is "in" *> fnBody)

    whereExpr =
      WhereExpr <$> fnBody <* is "where"
        <*> withinContext fnDefOrSig

    ifExpr =
      IfExpr <$> (is "if" *> openForm)
        <*> (is "then" *> openForm)
        <*> (is "else" *> openForm)

    multiWayIfExpr = MultiWayIfExpr <$> withinContext (guardedFnBody (is "->"))

    doExpr = DoExpr <$> (is "do" *> withinContext doStep)

    caseOfExpr =
      CaseOfExpr <$> (is "case" *> openForm <* is "of")
        <*> withinContext caseBinding

    tuple = Tuple <$> tupleOf openForm

    list = List <$> listOf openForm

    fnOp = VarOp' <$> varOp <|> CtorOp' <$> ctorOp

    fnVar = FnVar' . Var' <$> var <|> FnVar' . Ctor' <$> ctor

    literal' = Literal' <$> literal

    openForm = complexForm <|> singleForm

    delimitedForm = singleForm <|> withinParens complexForm

    singleForm = fnVar <|> literal' <|> tuple <|> list

    complexForm = infixFnApply <|> complexInfixForm

    complexInfixForm =
      fnApply <|> lambdaExpr
        <|> letExpr
        <|> ifExpr
        <|> multiWayIfExpr
        <|> doExpr
        <|> caseOfExpr
        <|> withinParens infixFnApply

-- <|> whereExpr

doStep :: Parser DoStep
doStep =
  DoBinding <$> var <* is "<-" <*> fnBody
    <|> Body <$> fnBody

caseBinding :: Parser CaseBinding
caseBinding = CaseBinding <$> pattern' <*> maybeGuardedFnBody (is "->")

maybeGuardedFnBody :: Parser a -> Parser MaybeGuardedFnBody
maybeGuardedFnBody sep =
  Guarded <$> withinContext (guardedFnBody sep)
    <|> Standard <$> (sep *> fnBody)

guardedFnBody :: Parser a -> Parser GuardedFnBody
guardedFnBody sep = GuardedFnBody <$> guard <* sep <*> fnBody

guard :: Parser Guard
guard = Guard <$> (is "|" *> someSepBy comma patternGuard)

patternGuard :: Parser PatternGuard
patternGuard =
  PatternGuard <$> (pattern' <* is "<-") <*> fnBody
    <|> SimpleGuard <$> fnBody
    <|> Otherwise <$ is "otherwise"

withinContext :: Parser b -> Parser [b]
withinContext parser = withinCurlyBrackets $ someSepBy (is ";") parser
