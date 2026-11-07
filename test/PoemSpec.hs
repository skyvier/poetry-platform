{-# LANGUAGE OverloadedStrings #-}
module PoemSpec (spec) where

import qualified Data.Text as T
import Test.Hspec

import Poem

parse :: T.Text -> Poem
parse src = either error id (parsePoem "meren-ranta" src)

spec :: Spec
spec = do
  describe "parsePoem" $ do
    it "keeps leading indentation exactly" $
      poemStanzas (parse "kivi\n  sammal\n    puro\n")
        `shouldBe` [["kivi", "  sammal", "    puro"]]

    it "collapses runs of blank lines into one stanza break" $
      poemStanzas (parse "yksi\n\n\n\nkaksi\nkolme\n")
        `shouldBe` [["yksi"], ["kaksi", "kolme"]]

    it "treats whitespace-only lines as blank" $
      poemStanzas (parse "yksi\n   \nkaksi\n")
        `shouldBe` [["yksi"], ["kaksi"]]

    it "drops leading and trailing blank lines" $
      poemStanzas (parse "\n\n  yksi\n\n\n")
        `shouldBe` [["  yksi"]]

    it "strips trailing whitespace" $
      poemStanzas (parse "sininen järvi \nhämärä,\t\n")
        `shouldBe` [["sininen järvi", "hämärä,"]]

    it "handles CRLF line endings" $
      poemStanzas (parse "yksi\r\n\r\nkaksi\r\n")
        `shouldBe` [["yksi"], ["kaksi"]]

    it "derives the title from the slug" $
      poemTitle (parse "rivi\n") `shouldBe` "meren ranta"

    it "uses a '# title' first line and removes it from the poem" $ do
      let p = parse "# syyspäivä\nlehdet\nputoavat hiljaa\n"
      poemTitle p `shouldBe` "syyspäivä"
      poemStanzas p `shouldBe` [["lehdet", "putoavat hiljaa"]]

    it "falls back to the slug title when '# ' is empty" $
      poemTitle (parse "#   \nrivi\n") `shouldBe` "meren ranta"

    it "rejects a poem without lines" $ do
      parsePoem "tyhja" "" `shouldSatisfy` isLeft
      parsePoem "tyhja" "# vain otsikko\n\n" `shouldSatisfy` isLeft

  describe "renderPoemHtml" $ do
    it "renders lines and stanza breaks, escaping HTML" $
      renderPoemHtml (parse "a < b & c\n  d\n\ne\n")
        `shouldBe` T.concat
          [ "<span class=\"line\">a &lt; b &amp; c</span>\n"
          , "<span class=\"line\" style=\"--indent:2\">d</span>\n"
          , "<span class=\"break\" aria-hidden=\"true\"></span>\n"
          , "<span class=\"line\">e</span>\n"
          ]

    it "counts a leading tab as four columns of indentation" $
      renderPoemHtml (parse "\t x\n")
        `shouldBe` "<span class=\"line\" style=\"--indent:5\">x</span>\n"

  describe "orderSlugs" $ do
    it "puts listed slugs first, then the rest alphabetically" $
      orderSlugs ["b", "", "d"] ["a", "b", "c", "d"]
        `shouldBe` Right ["b", "d", "a", "c"]

    it "works without an order list" $
      orderSlugs [] ["c", "a"] `shouldBe` Right ["a", "c"]

    it "ignores surrounding whitespace in the order list" $
      orderSlugs ["  c  "] ["a", "c"] `shouldBe` Right ["c", "a"]

    it "fails when the order list names a missing poem" $
      orderSlugs ["a", "kadonnut"] ["a"] `shouldSatisfy` isLeft

isLeft :: Either a b -> Bool
isLeft = either (const True) (const False)
