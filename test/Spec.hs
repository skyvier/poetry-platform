module Main (main) where

import Test.Hspec

import qualified PoemSpec
import qualified SealSpec

main :: IO ()
main = hspec $ do
  PoemSpec.spec
  SealSpec.spec
