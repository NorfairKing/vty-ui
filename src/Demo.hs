{-# OPTIONS_GHC -fno-warn-missing-signatures #-}
module Main where

import System.Exit ( exitSuccess )
import Control.Monad.Trans ( liftIO )
import Control.Monad.State ( StateT, get )

import Graphics.Vty
import Graphics.Vty.Widgets.All

-- The application state; this contains references to widgets that
-- need to be updated when events occur.
data AppState =
    AppState { theList :: Widget (List String FormattedText)
             , theMessages :: [(String, String)]
             , theBody :: Widget FormattedText
             , theFooter :: Widget FormattedText
             , theEdit :: Widget Edit
             , uis :: Widget Collection
             }

on :: Color -> Color -> Attr
on a b = def_attr `with_back_color` b `with_fore_color` a

-- Visual attributes.
titleAttr = bright_white `on` blue
editAttr = white `on` black
editFocusAttr = bright_green `on` blue
boxAttr = bright_yellow `on` black
bodyAttr = bright_green `on` black
selAttr = black `on` yellow
hlAttr1 = red `on` black
hlAttr2 = yellow `on` black

-- The data that we'll present in the interface.
messages :: [(String, String)]
messages = [ ("First", "This text is long enough that it will get wrapped \
                       \if you resize your terminal to something small. \
                       \It also contains enough text to get truncated at \
                       \the bottom if the display area is too small.\n\n\n" )
           , ("Second", "the second message")
           , ("Third", "the third message")
           , ("Fourth", "the fourth message")
           , ("Fifth", "the fifth message")
           , ("Sixth", "the sixth message")
           , ("Seventh", "the seventh message")
           ]

helpStr :: String
helpStr = " Enter: view  q: quit "

uiCore appst w = do
  (hBorder titleAttr)
      <--> w
      <--> (return $ theEdit appst)
      <--> ((return $ theFooter appst)
            <++> hBorder titleAttr
            <++> simpleText titleAttr helpStr)

buildUi1 appst =
    uiCore appst (bottomPadded (theList appst) bodyAttr)

buildUi2 appst =
    uiCore appst ((return $ theList appst)
                  <--> (hBorder titleAttr)
                  <--> (bottomPadded (theBody appst) bodyAttr))

updateUiFromState :: StateT AppState IO ()
updateUiFromState = do
  appst <- get
  (i, _) <- getSelected $ theList appst
  setText (theBody appst) (snd $ theMessages appst !! i) bodyAttr

  let msg = " " ++ (show $ i + 1) ++ "/" ++ (show $ length $ theMessages appst) ++ " "
  setText (theFooter appst) msg titleAttr

-- Construct the application state using the message map.
mkAppState :: IO AppState
mkAppState = do
  let labels = map fst messages

  lw <- listWidget =<< mkSimpleList bodyAttr selAttr 5 labels
  b <- textWidget wrap $ prepareText bodyAttr ""
  f <- simpleText titleAttr ""
  e <- editWidget editAttr editFocusAttr "foobar"

  c <- newCollection

  return $ AppState { theList = lw
                    , theMessages = messages
                    , theBody = b
                    , theFooter = f
                    , theEdit = e
                    , uis = c
                    }

main :: IO ()
main = do
  vty <- mkVty

  st <- mkAppState

  ui1 <- buildUi1 st
  ui2 <- buildUi2 st

  addToCollection (uis st) ui1
  addToCollection (uis st) ui2

  (fg, focusableList) <- newFocusGroup (theList st)
  addToFocusGroup_ fg (theEdit st)

  let exitApp = liftIO $ do
                  reserve_display $ terminal vty
                  shutdown vty
                  exitSuccess

      universalKeys =
          \_ k -> do
            case k of
              (KASCII 'q') -> exitApp
              _ -> return False

  focusableList `onKeyPressed` universalKeys

  (theList st) `onKeyPressed` \_ k -> do
         case k of
           KEnter -> setCurrent (uis st) 1 >> return True
           _ -> return False

  ui2 `onKeyPressed` \_ k -> do
         case k of
           KEsc -> setCurrent (uis st) 0 >> return True
           (KASCII 'w') -> setCurrent (uis st) 0 >> return True
           _ -> return False

  -- Enter the event loop.
  -- XXX rebuild widgets to pull state from appst on their own
  runUi vty (uis st) fg
