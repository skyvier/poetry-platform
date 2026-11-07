{-# LANGUAGE OverloadedStrings #-}
module Main (main) where

import Crypto.Random (getRandomBytes)
import Data.Aeson (encode, object, (.=))
import qualified Data.ByteString as B
import qualified Data.ByteString.Base16 as B16
import qualified Data.ByteString.Base64 as B64
import qualified Data.ByteString.Char8 as BC
import qualified Data.ByteString.Lazy as BL
import Data.List (isSuffixOf)
import qualified Data.Map as M
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import GHC.IO.Encoding (setLocaleEncoding, utf8)
import Hakyll
import System.Directory (doesFileExist, listDirectory)
import System.Environment (lookupEnv)
import System.FilePath (takeBaseName, (</>))

import Poem
import Seal

siteTitle :: String
siteTitle = "kirjaimia, jotka jätän piirtämättä"

orderFile :: FilePath
orderFile = "poems/order.txt"

poemFiles :: Pattern
poemFiles = "poems/*.txt" .&&. complement (fromGlob orderFile)

-- | Public, stable salt (hex). Keeping it fixed lets readers' browsers keep
-- the derived key across deploys.
saltFile :: FilePath
saltFile = "crypto-salt"

-- | PBKDF2 iterations; the browser repeats the same derivation.
iterations :: Int
iterations = 600000

data Keys = Keys { keySalt :: B.ByteString, keyAes :: B.ByteString }

main :: IO ()
main = do
  -- Poems are UTF-8 regardless of the build machine's locale.
  setLocaleEncoding utf8
  hakyll rules

rules :: Rules ()
rules = do
  order <- preprocess readOrder
  hasOrderFile <- preprocess (doesFileExist orderFile)
  keys <- preprocess loadKeys

  match ("css/*" .||. "js/*") $ do
    route idRoute
    compile copyFileCompiler

  match "templates/*" $ compile templateBodyCompiler

  match (fromGlob orderFile) $ compile getResourceBody

  -- Titles only, so pages can name their neighbours without depending on
  -- each other's full output.
  match poemFiles $ version "title" $
    compile $ poemCompiler >>= makeItem . T.unpack . poemTitle

  match poemFiles $ do
    route $ customRoute (\i -> slugOf i </> "index.html")
    compile $ do
      dependOnOrder hasOrderFile
      titles <- loadTitles
      poem <- poemCompiler
      slug <- slugOf <$> getUnderlying
      let title = T.unpack (poemTitle poem)
          next = case dropWhile (/= slug) order of
            (_ : n : _) -> Just n
            _           -> Nothing
          ctx = constField "title" (escapeHtml title)
             <> constField "poem" (T.unpack (renderPoemHtml poem))
             <> maybe mempty (\n -> constField "next-url" ("/" ++ n ++ "/")
                                  <> constField "next-title" (escapeHtml (M.findWithDefault n n titles))) next
             <> siteCtx
      makeItem ""
        >>= loadAndApplyTemplate "templates/poem.html" ctx
        >>= relativizeUrls
        >>= sealPage keys title

  create ["index.html"] $ do
    route idRoute
    compile $ do
      dependOnOrder hasOrderFile
      titles <- loadTitles
      entries <- mapM makeItem (zip [0 :: Int ..] order)
      let entryCtx = field "url" (pure . ("/" ++) . (++ "/") . snd . itemBody)
                  <> field "title" (\i -> let s = snd (itemBody i)
                                          in pure (escapeHtml (M.findWithDefault s s titles)))
                  <> field "i" (pure . show . fst . itemBody)
          ctx = listField "poems" entryCtx (pure entries) <> siteCtx
      makeItem ""
        >>= loadAndApplyTemplate "templates/index.html" ctx
        >>= relativizeUrls
        >>= sealPage keys ""

siteCtx :: Context String
siteCtx = constField "site-title" siteTitle <> defaultContext

-- | Encrypt a rendered page body and wrap it in the locked page shell. Only
-- the site title, salt and ciphertext are readable without the passphrase.
sealPage :: Keys -> String -> Item String -> Compiler (Item String)
sealPage keys title inner = do
  iv <- unsafeCompiler (getRandomBytes 12)
  let payload = BL.toStrict . encode $
        object ["title" .= title, "html" .= itemBody inner]
      sealed = BL.toStrict . encode $
        object [ "iv" .= b64 iv
               , "ct" .= b64 (seal (keyAes keys) iv payload) ]
      ctx = constField "sealed" (T.unpack (TE.decodeUtf8 sealed))
         <> constField "salt" (T.unpack (b64 (keySalt keys)))
         <> constField "iterations" (show iterations)
         <> siteCtx
  makeItem ""
    >>= loadAndApplyTemplate "templates/locked.html" ctx
    >>= loadAndApplyTemplate "templates/default.html" ctx
    >>= relativizeUrls
  where
    b64 = TE.decodeUtf8 . B64.encode

-- | Passphrase from $SITE_PASSPHRASE or a git-ignored .passphrase file.
loadKeys :: IO Keys
loadKeys = do
  saltHex <- BC.strip <$> B.readFile saltFile
  salt <- either (fail . ((saltFile ++ ": ") ++)) pure (B16.decode saltHex)
  env <- lookupEnv "SITE_PASSPHRASE"
  pass <- case env of
    Just p | not (null p) -> pure (TE.encodeUtf8 (T.pack p))
    _ -> do
      hasFile <- doesFileExist ".passphrase"
      if hasFile
        then TE.encodeUtf8 . T.dropWhileEnd (== '\n') . TE.decodeUtf8 <$> B.readFile ".passphrase"
        else pure B.empty
  if B.null pass
    then fail "No passphrase: set SITE_PASSPHRASE or create a .passphrase file"
    else pure (Keys salt (deriveKey pass salt iterations))

slugOf :: Identifier -> String
slugOf = takeBaseName . toFilePath

-- | Parse the current poem file; a malformed poem fails the build.
poemCompiler :: Compiler Poem
poemCompiler = do
  slug <- slugOf <$> getUnderlying
  src <- itemBody <$> getResourceBody
  either fail pure (parsePoem (T.pack slug) (T.pack src))

-- | Map of slug to title. Loading by pattern also makes the caller rebuild
-- whenever a poem is added, removed or retitled.
loadTitles :: Compiler (M.Map String String)
loadTitles = do
  items <- loadAll (poemFiles .&&. hasVersion "title")
  pure (M.fromList [(slugOf (itemIdentifier i), itemBody i) | i <- items])

dependOnOrder :: Bool -> Compiler ()
dependOnOrder True  = () <$ (load (fromFilePath orderFile) :: Compiler (Item String))
dependOnOrder False = pure ()

readOrder :: IO [String]
readOrder = do
  files <- filter isPoem <$> listDirectory "poems"
  hasOrder <- doesFileExist orderFile
  orderLines <- if hasOrder then T.lines . T.pack <$> readFile orderFile else pure []
  either fail (pure . map T.unpack)
    (orderSlugs orderLines (map (T.pack . takeBaseName) files))
  where
    isPoem f = ".txt" `isSuffixOf` f && f /= "order.txt"
