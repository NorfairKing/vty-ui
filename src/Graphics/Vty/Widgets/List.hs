-- |This module provides a 'List' widget for rendering a list of
-- single-line strings.  A 'List' has the following features:
--
-- * A style for the list elements
--
-- * A styled cursor indicating which element is selected
--
-- * A /window size/ indicating how many elements should be visible to
--   the user
--
-- * An internal pointer to the start of the visible window, which
--   automatically shifts as the list is scrolled
module Graphics.Vty.Widgets.List
    ( List
    , ListItem
    -- ** List creation
    , mkList
    -- ** List manipulation
    , scrollDown
    , scrollUp
    -- ** List inspection
    , listItems
    , getSelected
    , selectedIndex
    , scrollTopIndex
    , scrollWindowSize
    , getVisibleItems
    )
where

import Graphics.Vty ( Attr, vert_cat )
import Graphics.Vty.Widgets.Base
    ( Widget(..)
    , text
    , anyWidget
    , hFill
    )

-- |A list item. Each item contains an arbitrary internal identifier
-- @a@ and a label.
type ListItem a = (a, String)

-- |The list widget type.
data List a = List { normalAttr :: Attr
                   , selectedAttr :: Attr
                   , selectedIndex :: Int
                   -- ^The currently selected list index.
                   , scrollTopIndex :: Int
                   -- ^The start index of the window of visible list
                   -- items.
                   , scrollWindowSize :: Int
                   -- ^The size of the window of visible list items.
                   , listItems :: [ListItem a]
                   -- ^The items in the list.
                   }

-- |Create a new list.  Emtpy lists are not allowed.
mkList :: Attr -- ^The attribute of normal, non-selected items
       -> Attr -- ^The attribute of the selected item
       -> Int -- ^The scrolling window size, i.e., the number of items
              -- which should be visible to the user at any given time
       -> [ListItem a] -- ^The list items
       -> List a
mkList _ _ _ [] = error "Lists cannot be empty"
mkList normAttr selAttr swSize contents = List normAttr selAttr 0 0 swSize contents

-- note that !! here will always succeed because selectedIndex will
-- never be out of bounds and the list will always be non-empty.
-- |Get the currently selected list item.
getSelected :: List a -> ListItem a
getSelected list = (listItems list) !! (selectedIndex list)

-- |Scroll a list down one position and return the new scrolled list.
-- This automatically takes care of managing all list state:
--
-- * Moves the cursor down one position, unless the cursor is already
--   in the last position (in which case this does nothing)
--
-- * Moves the scrolling window position if necessary (i.e., if the
--   cursor moves to an item not currently in view)
scrollDown :: List a -> List a
scrollDown list
    -- If the list is already at the last position, do nothing.
    | selectedIndex list == length (listItems list) - 1 = list
    -- If the list requires scrolling the visible area, scroll it.
    | selectedIndex list == scrollTopIndex list + scrollWindowSize list - 1 =
        list { selectedIndex = selectedIndex list + 1
             , scrollTopIndex = scrollTopIndex list + 1
             }
    -- Otherwise, just increment the selectedIndex.
    | otherwise = list { selectedIndex = selectedIndex list + 1 }

-- |Scroll a list up one position and return the new scrolled list.
-- This automatically takes care of managing all list state:
--
-- * Moves the cursor up one position, unless the cursor is already
--   in the first position (in which case this does nothing)
--
-- * Moves the scrolling window position if necessary (i.e., if the
--   cursor moves to an item not currently in view)
scrollUp :: List a -> List a
scrollUp list
    -- If the list is already at the first position, do nothing.
    | selectedIndex list == 0 = list
    -- If the list requires scrolling the visible area, scroll it.
    | selectedIndex list == scrollTopIndex list =
        list { selectedIndex = selectedIndex list - 1
             , scrollTopIndex = scrollTopIndex list - 1
             }
    -- Otherwise, just decrement the selectedIndex.
    | otherwise = list { selectedIndex = selectedIndex list - 1 }

-- |Given a 'List', return the items that are currently visible
-- according to the state of the list.  Returns the visible items and
-- flags indicating whether each is selected.
getVisibleItems :: List a -> [(ListItem a, Bool)]
getVisibleItems list =
    let start = scrollTopIndex list
        stop = scrollTopIndex list + scrollWindowSize list
        adjustedStop = (min stop $ length $ listItems list) - 1
    in [ (listItems list !! i, i == selectedIndex list)
             | i <- [start..adjustedStop] ]

instance Widget (List a) where
    growHorizontal _ = False
    growVertical _ = False

    primaryAttribute = normalAttr

    render s w =
        vert_cat images
            where
              images = map (render s) (visible ++ filler)
              visible = map (anyWidget . mkWidget) items
              items = map (\((_, label), sel) -> (label, sel)) $ getVisibleItems w
              filler = replicate (scrollWindowSize w - length visible)
                       (anyWidget $ hFill (normalAttr w) ' ' 1)
              mkWidget (str, selected) = let att = if selected
                                                   then selectedAttr
                                                   else normalAttr
                                         in text (att w) str