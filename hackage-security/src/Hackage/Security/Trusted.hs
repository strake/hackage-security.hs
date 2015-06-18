{-# LANGUAGE CPP #-}
#if __GLASGOW_HASKELL__ >= 710
{-# LANGUAGE StaticPointers #-}
#endif
module Hackage.Security.Trusted (
    module Hackage.Security.Trusted.TCB
    -- * Derived functions
  , (<$$>)
    -- ** Role verification
  , verifyRoot
  , verifyTimestamp
  , verifySnapshot
  , verifyMirrors
    -- ** File info verification
  , verifyFileInfo
    -- ** Utility
  , formatVerificationError
  ) where

import Data.Time
import Hackage.Security.TUF
import Hackage.Security.Trusted.TCB hiding (DeclareTrusted)
import Hackage.Security.Util.Path

{-------------------------------------------------------------------------------
  Combinators on trusted values
-------------------------------------------------------------------------------}

-- | Apply a static function to a trusted argument
(<$$>) :: StaticPtr (a -> b) -> Trusted a -> Trusted b
(<$$>) = trustApply . trustStatic

{-------------------------------------------------------------------------------
  Role verification
-------------------------------------------------------------------------------}

-- | Verify (new) root info based on (old) root info
verifyRoot :: Trusted Root             -- ^ Trusted (old) root data
           -> Maybe UTCTime            -- ^ Time now (if checking expiry)
           -> Signed Root              -- ^ New root data to verify
           -> Either VerificationError (SignaturesVerified Root)
verifyRoot old =
     verifyRole (static (rootRolesRoot . rootRoles) <$$> old)
                (Just (rootVersion (trusted old)))

-- | Verify a timestamp
verifyTimestamp :: Trusted Root      -- ^ Trusted root data
                -> Maybe FileVersion -- ^ Previous version (if available)
                -> Maybe UTCTime     -- ^ Time now (if checking expiry)
                -> Signed Timestamp  -- ^ Timestamp to verify
                -> Either VerificationError (SignaturesVerified Timestamp)
verifyTimestamp root =
     verifyRole (static (rootRolesTimestamp . rootRoles) <$$> root)

-- | Verify snapshot
verifySnapshot :: Trusted Root       -- ^ Root data
               -> Maybe FileVersion  -- ^ Previous version (if available)
               -> Maybe UTCTime      -- ^ Time now (if checking expiry)
               -> Signed Snapshot    -- ^ Snapshot to verify
               -> Either VerificationError (SignaturesVerified Snapshot)
verifySnapshot root =
     verifyRole (static (rootRolesSnapshot . rootRoles) <$$> root)

-- | Verify mirrors
verifyMirrors :: Trusted Root       -- ^ Root data
              -> Maybe FileVersion  -- ^ Previous version (if available)
              -> Maybe UTCTime      -- ^ Time now (if checking expiry)
              -> Signed Mirrors     -- ^ Mirrors to verify
              -> Either VerificationError (SignaturesVerified Mirrors)
verifyMirrors root =
     verifyRole (static (rootRolesMirrors . rootRoles) <$$> root)

{-------------------------------------------------------------------------------
  File info verification
-------------------------------------------------------------------------------}

-- | Verify 'FileInfo'
verifyFileInfo :: Path -> Trusted FileInfo -> IO Bool
verifyFileInfo fp info = (== trusted info) <$> computeFileInfo fp

{-------------------------------------------------------------------------------
  Utility
-------------------------------------------------------------------------------}

formatVerificationError :: VerificationError -> String
formatVerificationError VerificationErrorSignatures =
    "Not enough signatures signed with the appropriate keys"
formatVerificationError (VerificationErrorExpired file) =
    file ++ " is expired"
formatVerificationError (VerificationErrorVersion file) =
    "Version of " ++ file ++ " is less than the previous version"
formatVerificationError (VerificationErrorFileInfo file) =
    "Invalid hash for " ++ file
formatVerificationError (VerificationErrorUnknownTarget file) =
    file ++ " not found in corresponding target metadata"
formatVerificationError (VerificationErrorFileTooLarge file) =
    file ++ " too large"
formatVerificationError VerificationErrorLoop =
    "Verification loop"