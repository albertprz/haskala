module SyntaxTrees.Haskell.FnDef where

import SyntaxTrees.Haskell.Common  (Literal, QCtor, QCtorOp, QVar, QVarOp, Var,
                                    VarOp)
import SyntaxTrees.Haskell.Pattern (Pattern)
import SyntaxTrees.Haskell.Type    (Type)



data FnSig
  = FnSig
      { name  :: Var
      , type' :: Type
      }
  deriving (Show)

data FnDef
  = FnDef
      { names :: [Var]
      , args  :: [Pattern]
      , body  :: MaybeGuardedFnBody
      }
  deriving (Show)

data InfixFnAnnotation
  = InfixFnAnnotation
      { associativity :: Associativity
      , precedence    :: Integer
      , name          :: VarOp
      }
  deriving (Show)

data FnDefOrSig
  = Def FnDef
  | Sig FnSig
  deriving (Show)

data FnBody
  = FnApply
      { fn   :: FnBody
      , args :: [FnBody]
      }
  | InfixFnApply
      { fnOps :: [FnOp]
      , args  :: [FnBody]
      }
  | LeftOpSection
      { fnOp :: FnOp
      , arg  :: FnBody
      }
  | RightOpSection
      { arg  :: FnBody
      , fnOp :: FnOp
      }
  | PostFixOpSection
      { arg  :: FnBody
      , fnOp :: FnOp
      }
  | LambdaExpr
      { patterns :: [Pattern]
      , body     :: FnBody
      }
  | LetExpr
      { fnBindings :: [FnDefOrSig]
      , body       :: FnBody
      }
  | WhereExpr
      { body       :: FnBody
      , fnBindings :: [FnDefOrSig]
      }
  | IfExpr
      { cond       :: FnBody
      , ifBranch   :: FnBody
      , elseBranch :: FnBody
      }
  | MultiWayIfExpr
      { whenExprs :: [GuardedFnBody]
      }
  | DoExpr
      { steps :: [DoStep]
      }
  | CaseOfExpr
      { matchee :: FnBody
      , cases   :: [CaseBinding]
      }
  | LambdaCaseExpr
      { cases :: [CaseBinding]
      }
  | RecordCreate
      { ctor        :: FnBody
      , namedFields :: [(Var, FnBody)]
      }
  | RecordUpdate
      { var         :: FnBody
      , namedFields :: [(Var, FnBody)]
      }
  | TypeAnnotation FnBody Type
  | ListRange FnBody (Maybe FnBody)
  | Tuple [FnBody]
  | List [FnBody]
  | FnVar' FnVar
  | Literal' Literal
  deriving (Show)

data FnVar
  = Selector Var
  | Selection QVar [Var]
  | Var' QVar
  | Ctor' QCtor
  deriving (Show)

data FnOp
  = VarOp' QVarOp
  | CtorOp' QCtorOp
  deriving (Show)

data DoStep
  = DoBinding [Var] FnBody
  | LetBinding [FnDefOrSig]
  | Body FnBody
  deriving (Show)

data CaseBinding
  = CaseBinding Pattern MaybeGuardedFnBody
  deriving (Show)

data MaybeGuardedFnBody
  = Guarded [GuardedFnBody]
  | Standard FnBody
  deriving (Show)

data GuardedFnBody
  = GuardedFnBody
      { guard :: Guard
      , body  :: FnBody
      }
  deriving (Show)

data Guard
  = Guard [PatternGuard]
  | Otherwise
  deriving (Show)

data PatternGuard
  = PatternGuard Pattern FnBody
  | SimpleGuard FnBody
  deriving (Show)

data Associativity
  = LAssoc
  | RAssoc
  deriving (Show)
