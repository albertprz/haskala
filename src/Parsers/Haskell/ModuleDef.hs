module Parsers.Haskell.ModuleDef where


import Parsers.Haskell.ClassDef      (classDef, instanceDef)
import Parsers.Haskell.Common        (module', var)
import Parsers.Haskell.DataDef       (dataDef, newtypeDef, typeDef)
import Parsers.Haskell.FnDef         (fnDef, fnSig, withinContextTupled)
import Parsers.Haskell.Type          (typeVar)
import SyntaxTrees.Haskell.ModuleDef (InternalDef (..), ModuleDef (ModuleDef),
                                      ModuleExport (ModuleExport),
                                      ModuleExportDef (DataExport, FilteredDataExport, FnExport, FullDataExport),
                                      ModuleImport (ModuleImport),
                                      ModuleImportDef (DataImport, FilteredDataImport, FnImport, FullDataImport))

import Parser                    (Parser)
import ParserCombinators         (IsMatch (is), anySepBy, (<|>), (|?))
import Parsers.Char              (comma)
import Parsers.String            (withinParens)
import SyntaxTrees.Haskell.FnDef (FnDefOrSig (Def, Sig))


moduleDef :: Parser ModuleDef
moduleDef = uncurry <$>
              (ModuleDef <$> (is "module" *> module')
                         <*  is "where"
                         <*> (moduleExport |?))
                         <*> withinContextTupled moduleImport internalDef



moduleExport :: Parser ModuleExport
moduleExport = ModuleExport <$> withinParens (anySepBy comma moduleExportDef)


moduleExportDef :: Parser ModuleExportDef
moduleExportDef = FnExport            <$> var                   <|>
                  DataExport          <$> typeVar               <|>
                  FullDataExport      <$> typeVar
                                      <* withinParens (is "..") <|>
                  FilteredDataExport  <$> typeVar
                                      <*> withinParens (anySepBy comma var)

moduleImport :: Parser ModuleImport
moduleImport = ModuleImport <$> (is "import" *> module')
                            <*> withinParens (anySepBy comma moduleImportDef)


moduleImportDef :: Parser ModuleImportDef
moduleImportDef = FnImport            <$> var                   <|>
                  DataImport          <$> typeVar               <|>
                  FullDataImport      <$> typeVar
                                      <* withinParens (is "..") <|>
                  FilteredDataImport  <$> typeVar
                                      <*> withinParens (anySepBy comma var)



internalDef :: Parser InternalDef
internalDef = TypeDef'          <$> typeDef      <|>
              NewTypeDef'       <$> newtypeDef   <|>
              DataDef'          <$> dataDef      <|>
              FnDefOrSig' . Def <$> fnDef        <|>
              FnDefOrSig' . Sig <$> fnSig        <|>
              ClassDef'         <$> classDef     <|>
              InstanceDef'      <$> instanceDef
