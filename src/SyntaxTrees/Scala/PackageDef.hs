module SyntaxTrees.Scala.PackageDef where

import Data.List                 (intercalate)
import SyntaxTrees.Scala.Common  (Package, Var, VarOp)
import SyntaxTrees.Scala.DataDef (InternalDef)
import SyntaxTrees.Scala.Type    (TypeVar)
import Utils.String


data PackageDef
  = PackageDef
      { name    :: Package
      , imports :: [PackageImport]
      , defs    :: [InternalDef]
      }

data PackageImport
  = PackageImport
      { package   :: Package
      , alias     :: Maybe Package
      , importDef :: Maybe PackageImportDef
      }

data PackageImportDef
  = FullImport
  | MembersImport [PackageMember]
  | FullObjectImport TypeVar
  | FilteredObjectImport TypeVar [PackageMember]

data PackageMember
  = VarMember Var
  | VarOpMember VarOp
  | DataMember TypeVar


instance Show PackageDef where
  show (PackageDef x y z) =
    joinLines ["package" +++ show x,
               intercalate "\n" (show <$> y),
               joinLines (show <$> z)]

instance Show PackageImport where
  show (PackageImport x y z) =
    joinWords ["import",
               show x,
               "as" `joinMaybe` y]
    ++ "." `joinMaybe` z

instance Show PackageImportDef where
  show FullImport                   = "_"
  show (MembersImport [x])          = show x
  show (MembersImport x)            = wrapCurlyCsv x
  show (FullObjectImport x)         = show x ++ "." ++ "_"
  show (FilteredObjectImport x [y]) = show x ++ "." ++ show y
  show (FilteredObjectImport x y)   = show x ++ "." ++ wrapCurlyCsv y

instance Show PackageMember where
  show (VarMember x)   = show x
  show (VarOpMember x) = show x
  show (DataMember x)  = show x
