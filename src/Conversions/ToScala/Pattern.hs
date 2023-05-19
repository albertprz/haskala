module Conversions.ToScala.Pattern where

import qualified SyntaxTrees.Haskell.Common  as H
import qualified SyntaxTrees.Haskell.Pattern as H
import qualified SyntaxTrees.Scala.Common    as S
import qualified SyntaxTrees.Scala.Pattern   as S

import Conversions.ToScala.Common
import Data.Maybe                 (mapMaybe)


pattern' :: H.Pattern -> S.Pattern
pattern' (H.CtorPattern x y) = S.CtorPattern (qCtor x) (pattern' <$> y)
pattern' (H.InfixCtorPattern x y) = S.InfixCtorPattern (qCtorOp x) (pattern' <$> y)
pattern' (H.RecordPattern x y) = S.CtorPattern (qCtor x)
                                               (S.VarPattern . var . fst <$> y)
pattern' (H.WildcardRecordPattern x y) = S.CtorPattern (qCtor x)
                                               (S.VarPattern . var . fst <$> y)
pattern' (H.AliasedPattern x y) = S.AliasedPattern (var x) (pattern' y)
pattern' (H.ListPattern x) = S.CtorPattern  (S.QCtor Nothing $ S.Ctor "List") (pattern' <$> x)
pattern' (H.TuplePattern x) = S.TuplePattern $ pattern' <$> x
pattern' (H.VarPattern x) = S.VarPattern $ var x
pattern' (H.LitPattern x) = S.LitPattern $ literal x
pattern' H.Wildcard = S.Wildcard


extractVar :: H.Pattern -> Maybe H.Var
extractVar (H.VarPattern x) = Just x
extractVar _                = Nothing

extractVars :: [H.Pattern] -> [H.Var]
extractVars x = mapMaybe extractVar x

allVars :: [H.Pattern] -> Bool
allVars x = length (mapMaybe extractVar x) == length x

extractVar' :: S.Pattern -> Maybe S.Var
extractVar' (S.VarPattern x) = Just x
extractVar' _                = Nothing

extractVars' :: [S.Pattern] -> [S.Var]
extractVars' x = mapMaybe extractVar' x

allVars' :: [S.Pattern] -> Bool
allVars' x = length (mapMaybe extractVar' x) == length x
