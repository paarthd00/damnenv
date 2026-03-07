import XMonad
import XMonad.Util.EZConfig (additionalKeysP)
import XMonad.Hooks.StatusBar
import XMonad.Hooks.StatusBar.PP
import XMonad.Hooks.ManageDocks
import qualified XMonad.StackSet as W

import Colors

windowCount :: X (Maybe String)
windowCount = gets $ Just . show . length . W.integrate'
            . W.stack . W.workspace . W.current . windowset

myXmobarPP :: PP
myXmobarPP = def
    { ppCurrent         = xmobarColor colorCurrent     "" . wrap "[" "]"
    , ppVisible         = xmobarColor colorVisible     "" . wrap "(" ")"
    , ppHidden          = xmobarColor colorHidden      ""
    , ppHiddenNoWindows = xmobarColor colorHiddenNoWin ""
    , ppTitle           = xmobarColor colorTitle       "" . shorten 60
    , ppSep             = "  |  "
    , ppLayout          = xmobarColor colorLayout      ""
    , ppExtras          = [windowCount]
    , ppOrder           = \(ws:l:t:ex) -> [ws, l] ++ ex ++ [t]
    }

main :: IO ()
main = xmonad
     . docks
     . withEasySB (statusBarProp "xmobar ~/xmobarrc" (pure myXmobarPP)) defToggleStrutsKey
     $ def
        { terminal = "alacritty"
        , modMask  = mod4Mask
        , borderWidth = 0
        } `additionalKeysP`
        [ ("C-M-t",                   spawn "alacritty")
        , ("<F5>",                    spawn "~/.local/bin/brightness down")
        , ("<F6>",                    spawn "~/.local/bin/brightness up")
        , ("<XF86AudioMute>",         spawn "pactl set-sink-mute @DEFAULT_SINK@ toggle")
        , ("<XF86AudioLowerVolume>",  spawn "pactl set-sink-volume @DEFAULT_SINK@ -5%")
        , ("<XF86AudioRaiseVolume>",  spawn "pactl set-sink-volume @DEFAULT_SINK@ +5%")
        ]
