module Parsers.Haskell.Type where

import Parser                     (Parser)
import ParserCombinators          (IsMatch (is), manySepBy, someSepBy, (<|>),
                                   (|+))
import Parsers.Char               (comma, dot, lower, upper)
import Parsers.Collections        (tupleOf)
import Parsers.Haskell.Common     (class', ident, qClass, qTerm)
import Parsers.Number             ()
import Parsers.String             (maybeWithinParens, withinParens,
                                   withinSquareBrackets)
import SyntaxTrees.Haskell.Common ()
import SyntaxTrees.Haskell.Type   (AnyKindedType (..), ClassConstraint (..),
                                   QTypeCtor (QTypeCtor), QTypeVar (QTypeVar),
                                   Type (..), TypeCtor (..), TypeParam (..),
                                   TypeVar (..))

typeParam :: Parser TypeParam
typeParam = TypeParam <$> ident lower

typeVar :: Parser TypeVar
typeVar = TypeVar  <$> ident upper <|>
          UnitType <$ is "()"

typeCtor :: Parser TypeCtor
typeCtor = TypeCtor  <$> ident upper <|>
           Arrow     <$  is "(->)"   <|>
           TupleType <$  is "(,)"    <|>
           ListType  <$  is "[]"

anyKindedType :: Parser AnyKindedType
anyKindedType = TypeValue <$> type'     <|>
                TypeFn    <$> qTypeCtor


classConstraints :: Parser Type -> Parser [ClassConstraint]
classConstraints typeParser = tupleOf (classConstraint typeParser) <|>
                pure <$> classConstraint typeParser

classConstraint :: Parser Type -> Parser ClassConstraint
classConstraint typeParser = ClassConstraint <$> qClass <*> (typeParser |+)



type' :: Parser Type
type' = typeScope <|> classScope <|> type'' <|> maybeWithinParens (type'')
  where
    type'' = arrow <|> typeApply <|> elem'

    typeApply = CtorTypeApply   <$> qTypeCtor <*> (typeApplyElem |+) <|>
                ParamTypeApply  <$> typeParam <*> (typeApplyElem |+) <|>
                NestedTypeApply <$> withinParens typeApply <*> (typeApplyElem |+)

    arrow = CtorTypeApply (QTypeCtor Nothing Arrow)
            <$> manySepBy (is "->") arrowElem
    tuple = CtorTypeApply (QTypeCtor Nothing TupleType)
            <$> (withinParens $ manySepBy comma type'')
    list  = CtorTypeApply (QTypeCtor Nothing ListType)
            <$> (pure <$> withinSquareBrackets type'')

    typeVar'   = TypeVar'   <$> qTypeVar
    typeParam' = TypeParam' <$> typeParam

    typeScope = TypeScope <$> (is "forall" *> someSepBy dot typeParam <* dot)
                          <*> (classScope <|> type'')
    classScope = ClassScope <$> (classConstraints' <* (is "=>"))
                            <*> type''

    classConstraints' = classConstraints
                        (elem' <|> withinParens (arrow <|> typeApply))


    typeApplyElem = elem' <|> withinParens (arrow <|> typeApply)
    arrowElem     = typeApply <|> elem' <|> withinParens arrow

    elem' = typeVar' <|> typeParam' <|> tuple <|> list <|>
            withinParens (typeScope <|> classScope)

qTypeVar :: Parser QTypeVar
qTypeVar = uncurry QTypeVar <$> qTerm typeVar

qTypeCtor :: Parser QTypeCtor
qTypeCtor = uncurry QTypeCtor <$> qTerm typeCtor
