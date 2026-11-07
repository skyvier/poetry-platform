-- | Passphrase-based encryption matching the browser's WebCrypto:
-- PBKDF2-HMAC-SHA256 for the key, AES-256-GCM with the 16-byte tag appended
-- to the ciphertext (WebCrypto's layout).
module Seal (deriveKey, seal, open) where

import Crypto.Cipher.AES (AES256)
import Crypto.Cipher.Types (AEAD, AEADMode (AEAD_GCM), AuthTag (..), aeadInit,
                            aeadSimpleDecrypt, aeadSimpleEncrypt, cipherInit)
import Crypto.Error (throwCryptoError)
import qualified Crypto.KDF.PBKDF2 as PBKDF2
import qualified Data.ByteArray as BA
import Data.ByteString (ByteString)
import qualified Data.ByteString as B

-- | 32-byte key from passphrase, salt and iteration count.
deriveKey :: ByteString -> ByteString -> Int -> ByteString
deriveKey pass salt iters =
  PBKDF2.fastPBKDF2_SHA256 (PBKDF2.Parameters iters 32) pass salt

tagLength :: Int
tagLength = 16

-- | Encrypt with a 32-byte key and 12-byte IV; returns ciphertext || tag.
seal :: ByteString -> ByteString -> ByteString -> ByteString
seal key iv plain =
  let (AuthTag tag, ct) = aeadSimpleEncrypt (gcm key iv) B.empty plain tagLength
  in ct <> BA.convert tag

-- | Inverse of 'seal'; 'Nothing' if the key is wrong or data was altered.
open :: ByteString -> ByteString -> ByteString -> Maybe ByteString
open key iv sealed
  | B.length sealed < tagLength = Nothing
  | otherwise =
      let (ct, tag) = B.splitAt (B.length sealed - tagLength) sealed
      in aeadSimpleDecrypt (gcm key iv) B.empty ct (AuthTag (BA.convert tag))

gcm :: ByteString -> ByteString -> AEAD AES256
gcm key iv = throwCryptoError (cipherInit key >>= \c -> aeadInit AEAD_GCM (c :: AES256) iv)
