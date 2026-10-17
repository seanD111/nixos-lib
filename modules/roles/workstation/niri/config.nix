{ config, lib, ... }:
let
  # Drop-in fragments under /etc/niri/config.d are included at the bottom of
  # the config, mirroring sway's `include /etc/sway/config.d/*`. niri has no
  # glob include, so one `include` line is generated per fragment present.
  fragmentNames = builtins.filter (name: lib.hasPrefix "niri/config.d/" name) (
    builtins.attrNames config.environment.etc
  );

  includeLines = lib.concatStringsSep "\n" (map (name: "include \"/etc/${name}\"") fragmentNames);
in
{
  environment.etc."niri/config.kdl".text = ''
    // niri system-wide configuration, managed by NixOS.
    //
    // This is the system default: niri loads it when a user has no
    // ~/.config/niri/config.kdl. Copy it there to customize. The wiki has a
    // complete reference:
    // https://niri-wm.github.io/niri

    // Mod is Super (the logo key) when niri runs as a session. The terminal
    // is foot and the application launcher is fuzzel.

    // Input configuration.
    // Find the full list of options on the wiki:
    // https://niri-wm.github.io/niri/Configuration:-Input
    //
    //   input {
    //       touchpad {
    //           tap
    //           natural-scroll
    //       }
    //   }

    // Output configuration.
    // Configure outputs by name, which you can find by running `niri msg
    // outputs`.
    //
    //   output "DP-1" {
    //       mode "1920x1080"
    //   }

    // Settings that influence how windows are positioned and sized.
    layout {
        gaps 8

        // Widths cycled by Mod+R.
        preset-column-widths {
            proportion 0.33333
            proportion 0.5
            proportion 0.66667
        }
    }

    // The cheat-sheet wallpaper lists the important hotkeys, so the popup is
    // skipped at startup (it stays available with Mod+Shift+/).
    hotkey-overlay {
        skip-at-startup
    }

    binds {
        // Basics:
        Mod+Return { spawn "foot"; } // Start a terminal
        Mod+Shift+Q { close-window; } // Kill focused window
        Mod+D { spawn "fuzzel"; } // Start your launcher
        Mod+O repeat=false { toggle-overview; } // Toggle the Overview
        Mod+Shift+E { quit; } // Exit niri (asks for confirmation)
        Mod+Shift+Slash { show-hotkey-overlay; } // Show the hotkey overlay
        Super+Alt+L { spawn "swaylock"; } // Lock the screen

        // Moving around:
        Mod+Left { focus-column-left; } // Focus left
        Mod+Down { focus-window-down; } // Focus down
        Mod+Up { focus-window-up; } // Focus up
        Mod+Right { focus-column-right; } // Focus right
        Mod+H { focus-column-left; } // Focus left
        Mod+J { focus-window-down; } // Focus down
        Mod+K { focus-window-up; } // Focus up
        Mod+L { focus-column-right; } // Focus right

        // Move the focused window with the same keys plus Ctrl
        Mod+Ctrl+Left { move-column-left; } // Move column left
        Mod+Ctrl+Down { move-window-down; } // Move window down
        Mod+Ctrl+Up { move-window-up; } // Move window up
        Mod+Ctrl+Right { move-column-right; } // Move column right
        Mod+Ctrl+H { move-column-left; } // Move column left
        Mod+Ctrl+J { move-window-down; } // Move window down
        Mod+Ctrl+K { move-window-up; } // Move window up
        Mod+Ctrl+L { move-column-right; } // Move column right

        // Workspaces:
        Mod+U { focus-workspace-down; } // Focus the next workspace
        Mod+I { focus-workspace-up; } // Focus the previous workspace
        Mod+1 { focus-workspace 1; } // Switch to workspace 1
        Mod+2 { focus-workspace 2; } // Switch to workspace 2
        Mod+3 { focus-workspace 3; } // Switch to workspace 3
        Mod+4 { focus-workspace 4; } // Switch to workspace 4
        Mod+5 { focus-workspace 5; } // Switch to workspace 5
        Mod+6 { focus-workspace 6; } // Switch to workspace 6
        Mod+7 { focus-workspace 7; } // Switch to workspace 7
        Mod+8 { focus-workspace 8; } // Switch to workspace 8
        Mod+9 { focus-workspace 9; } // Switch to workspace 9
        Mod+Ctrl+1 { move-column-to-workspace 1; } // Move focused column to workspace 1
        Mod+Ctrl+2 { move-column-to-workspace 2; } // Move focused column to workspace 2
        Mod+Ctrl+3 { move-column-to-workspace 3; } // Move focused column to workspace 3
        Mod+Ctrl+4 { move-column-to-workspace 4; } // Move focused column to workspace 4
        Mod+Ctrl+5 { move-column-to-workspace 5; } // Move focused column to workspace 5
        Mod+Ctrl+6 { move-column-to-workspace 6; } // Move focused column to workspace 6
        Mod+Ctrl+7 { move-column-to-workspace 7; } // Move focused column to workspace 7
        Mod+Ctrl+8 { move-column-to-workspace 8; } // Move focused column to workspace 8
        Mod+Ctrl+9 { move-column-to-workspace 9; } // Move focused column to workspace 9

        // Layout stuff:
        Mod+BracketLeft { consume-or-expel-window-left; } // Consume or expel a window from the left column
        Mod+BracketRight { consume-or-expel-window-right; } // Consume or expel a window from the right column
        Mod+F { fullscreen-window; } // Make the current focus fullscreen
        Mod+W { toggle-column-tabbed-display; } // Toggle tabbed display for the column
        Mod+V { toggle-window-floating; } // Toggle the window between tiling and floating
        Mod+Space { switch-focus-between-floating-and-tiling; } // Swap focus between tiling and floating
        Mod+C { center-column; } // Center the focused column

        // Resizing containers:
        Mod+R { switch-preset-column-width; } // Cycle preset column widths
        Mod+Minus { set-column-width "-10%"; } // Shrink the focused column
        Mod+Equal { set-column-width "+10%"; } // Grow the focused column
        Mod+Shift+Minus { set-window-height "-10%"; } // Shrink the focused window
        Mod+Shift+Equal { set-window-height "+10%"; } // Grow the focused window

        // Utilities:
        XF86AudioRaiseVolume allow-when-locked=true { spawn-sh "pamixer -i 5"; } // Raise volume
        XF86AudioLowerVolume allow-when-locked=true { spawn-sh "pamixer -d 5"; } // Lower volume
        XF86AudioMute allow-when-locked=true { spawn-sh "pamixer -t"; } // Mute output
        XF86AudioMicMute allow-when-locked=true { spawn-sh "pamixer --default-source -t"; } // Mute microphone
        XF86MonBrightnessUp allow-when-locked=true { spawn "brightnessctl" "set" "5%+"; } // Raise brightness
        XF86MonBrightnessDown allow-when-locked=true { spawn "brightnessctl" "set" "5%-"; } // Lower brightness
        Print { screenshot; } // Take a screenshot
        Mod+Shift+P { power-off-monitors; } // Power off the monitors
    }

    // niri reloads the configuration automatically whenever the file changes.

    // waybar is started by the user systemd graphical-session.target, so no
    // spawn-at-startup is needed for it here.

    // Drop-in configuration fragments, mirroring sway's include of
    // /etc/sway/config.d.
    ${includeLines}
  '';
}
