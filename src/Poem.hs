{-# LANGUAGE OverloadedStrings #-}
-- | Plain-text poems: parsing, HTML rendering and ordering.
--
-- Deliberately independent of Hakyll so it can be tested on its own.
module Poem
  ( Poem (..)
  , parsePoem
  , renderPoemHtml
  , orderSlugs
  ) where

import Data.List (sort)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as T

data Poem = Poem
  { poemTitle   :: Text
  , poemStanzas :: [[Text]]  -- ^ non-empty stanzas of verbatim lines
  } deriving (Eq, Show)

-- | Parse a poem file. The slug provides the fallback title.
--
-- Leading indentation is kept exactly; trailing whitespace is stripped; runs
-- of blank lines become a single stanza break. An optional first line
-- @# title@ sets the title.
parsePoem :: Text -> Text -> Either String Poem
parsePoem slug src =
  case stanzas body of
    [] -> Left ("poem '" <> T.unpack slug <> "' has no lines")
    ss -> Right (Poem title ss)
  where
    ls = dropWhile isBlank (map T.stripEnd (T.lines src))
    (title, body) = case ls of
      (l : rest) | Just t <- T.stripPrefix "#" l ->
        let t' = T.strip t
        in (if T.null t' then slugTitle else t', rest)
      _ -> (slugTitle, ls)
    slugTitle = T.replace "-" " " slug

stanzas :: [Text] -> [[Text]]
stanzas ls = case break isBlank (dropWhile isBlank ls) of
  ([], _)      -> []
  (st, rest)   -> st : stanzas rest

isBlank :: Text -> Bool
isBlank = T.null . T.strip

-- | One element per line, with an aria-hidden spacer between stanzas.
-- Leading whitespace becomes an @--indent@ column count (tab = 4).
renderPoemHtml :: Poem -> Text
renderPoemHtml =
  T.concat . concat . interleave breakEl . map (map lineEl) . poemStanzas
  where
    lineEl l =
      let (lead, text) = T.span (`elem` [' ', '\t']) l
          cols = sum [if c == '\t' then 4 else 1 | c <- T.unpack lead] :: Int
          indent | cols == 0 = ""
                 | otherwise = " style=\"--indent:" <> T.pack (show cols) <> "\""
      in "<span class=\"line\"" <> indent <> ">" <> escape text <> "</span>\n"
    breakEl  = ["<span class=\"break\" aria-hidden=\"true\"></span>\n"]
    interleave sep (x : y : rest) = x : sep : interleave sep (y : rest)
    interleave _ xs = xs

escape :: Text -> Text
escape = T.concatMap esc
  where
    esc '<' = "&lt;"
    esc '>' = "&gt;"
    esc '&' = "&amp;"
    esc '"' = "&quot;"
    esc c   = T.singleton c

-- | Order slugs: those in the order list first (in its order), the rest
-- alphabetically. Fails if the list names a slug that does not exist.
orderSlugs :: [Text] -> [Text] -> Either String [Text]
orderSlugs orderLines available =
  case filter (`Set.notMember` known) listed of
    [] -> Right (listed ++ sort (filter (`Set.notMember` Set.fromList listed) available))
    missing -> Left ("order.txt names poems that do not exist: "
                     <> T.unpack (T.intercalate ", " missing))
  where
    known  = Set.fromList available
    listed = filter (not . T.null) (map T.strip orderLines)
