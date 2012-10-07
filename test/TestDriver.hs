{-# OPTIONS_GHC -fno-warn-orphans #-}
module Main where

import System.Exit ( exitFailure, exitSuccess )
import Test.QuickCheck
import Test.QuickCheck.Test

import qualified Tests.FormattedText as FormattedText
import qualified Tests.Tokenize as Tokenize
import qualified Tests.Edit as Edit
import qualified Tests.TextClip as TextClip

tests :: [Property]
tests = concat [ FormattedText.tests
               , Tokenize.tests
               , Edit.tests
               , TextClip.tests
               ]

main :: IO ()
main = do
  results <- mapM (quickCheckWithResult (stdArgs { maxSuccess = 200 })) tests
  if all isSuccess results then
      exitSuccess else
      exitFailure