{-# LANGUAGE OverloadedStrings #-}
module SealSpec (spec) where

import qualified Data.ByteString as B
import qualified Data.ByteString.Base16 as B16
import Data.ByteString (ByteString)
import Test.Hspec

import Seal

hex :: ByteString -> ByteString
hex = either error id . B16.decode

spec :: Spec
spec = do
  describe "deriveKey (PBKDF2-HMAC-SHA256)" $ do
    it "matches the published vector for 1 iteration" $
      deriveKey "password" "salt" 1
        `shouldBe` hex "120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b"
    it "matches the published vector for 2 iterations" $
      deriveKey "password" "salt" 2
        `shouldBe` hex "ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43"

  describe "seal (AES-256-GCM, ciphertext || tag)" $ do
    let key = B.replicate 32 0
        iv  = B.replicate 12 0
    it "matches the NIST vector for an empty plaintext" $
      seal key iv "" `shouldBe` hex "530f8afbc74536b9a963b4f1c4cb738b"
    it "matches the NIST vector for one zero block" $
      seal key iv (B.replicate 16 0)
        `shouldBe` hex "cea7403d4d606b6e074ec5d3baf39d18d0d1c8a799996bf0265b98b5d48ab919"
    it "round-trips through open" $
      open key iv (seal key iv "kuu ja ranta") `shouldBe` Just "kuu ja ranta"
    it "rejects a wrong key" $
      open (B.replicate 32 1) iv (seal key iv "kuu") `shouldBe` Nothing
