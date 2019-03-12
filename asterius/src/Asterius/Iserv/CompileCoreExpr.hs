module Asterius.Iserv.CompileCoreExpr
  ( compileCoreExpr
  ) where

import Asterius.CodeGen
import Asterius.Iserv.Trace
import Asterius.Linker.LinkExpr
import qualified CmmInfo as GHC
import Control.Exception
import qualified CorePrep as GHC
import qualified CoreSyn as GHC
import qualified CoreTidy as GHC
import qualified CoreToStg as GHC
import qualified CoreUtils as GHC
import qualified CostCentre as GHC
import Data.IORef
import Data.Tuple
import qualified GHCi.RemoteTypes as GHC
import qualified HscMain as GHC
import qualified HscTypes as GHC
import qualified Id as GHC
import Language.Haskell.GHC.Toolkit.Orphans.Show ()
import qualified Module as GHC
import qualified Name as GHC
import qualified SimplCore as GHC
import qualified SimplStg as GHC
import qualified SrcLoc as GHC
import qualified Stream
import qualified UniqSupply as GHC
import Unsafe.Coerce
import qualified VarEnv as GHC

compileCoreExpr ::
     Bool
  -> IORef GHC.UniqSupply
  -> GHC.HscEnv
  -> GHC.SrcSpan
  -> GHC.CoreExpr
  -> IO GHC.ForeignHValue
compileCoreExpr verbose us_ref hsc_env src_span ds_expr = do
  let dflags = GHC.hsc_dflags hsc_env
  simpl_expr <- GHC.simplifyExpr dflags ds_expr
  let tidy_expr = GHC.tidyExpr GHC.emptyTidyEnv simpl_expr
  prepd_expr <- GHC.corePrepExpr dflags hsc_env tidy_expr
  u <- atomicModifyIORef' us_ref $ swap . GHC.takeUniqFromSupply
  let this_mod =
        GHC.mkModule
          (GHC.stringToUnitId "asdf")
          (GHC.mkModuleName $ "ASDF" <> show u)
      occ_n = GHC.mkVarOcc "asdf"
      n = GHC.mkExternalName u this_mod occ_n src_span
      b = GHC.mkVanillaGlobal n (GHC.exprType ds_expr)
      prepd_binds = [GHC.NonRec b prepd_expr]
      (stg_binds, _) = GHC.coreToStg dflags this_mod prepd_binds
  stg_binds2 <- GHC.stg2stg dflags this_mod stg_binds
  cmms <-
    GHC.doCodeGen
      hsc_env
      this_mod
      []
      GHC.emptyCollectedCCs
      stg_binds2
      (GHC.emptyHpcInfo False)
  raw_cmms <- GHC.cmmToRawCmm dflags (Just this_mod) cmms >>= Stream.collect
  m <-
    either throwIO pure $
    runCodeGen (marshalRawCmm this_mod raw_cmms) dflags this_mod
  trace verbose $ show ds_expr
  trace verbose $ show $ GHC.exprType ds_expr
  trace verbose $ show m
  linkCoreExpr verbose hsc_env src_span prepd_expr
  GHC.mkForeignRef (unsafeCoerce $ GHC.RemotePtr 0) (pure ())