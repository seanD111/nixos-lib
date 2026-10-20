{ pkgs, ... }:
{
  # Tooling and session plumbing shared by every graphical Wayland session on
  # this workstation role. Imported by the individual compositor modules, not
  # by the workstation role itself: enabling greetd at the role level would
  # conflict with the getty autologin some tests rely on.

  programs = {
    foot.enable = true;
    waybar.enable = true;
  };

  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --sessions /run/current-system/sw/share/wayland-sessions";
      user = "greeter";
    };
  };

  environment = {
    systemPackages = with pkgs; [
      swaylock
      swayidle
      mako
      fuzzel
      grim
      slurp
      wl-clipboard
      cliphist
      brightnessctl
      pamixer
      wlsunset

      # File browsers: a GUI one (also provides a nice library view for
      # portal pickers) and a TUI one for the terminal.
      nautilus
      yazi

      # Authentication agent for polkit prompts; no compositor here ships one.
      lxqt.lxqt-policykit
    ];

    # Without this, /run/current-system/sw/share/wayland-sessions is never
    # populated (only XDG_DATA_DIRS exposes the session files) and the tuigreet
    # session list comes up empty.
    pathsToLink = [ "/share/wayland-sessions" ];

    # Electron and Chromium apps default to the X11 backend and run through
    # XWayland; the nixpkgs wrappers use this variable to switch them to native
    # Wayland (sharp fractional scaling, per-monitor DPI, Wayland IME). The
    # wrappers also require WAYLAND_DISPLAY, so it is inert elsewhere.
    # https://wiki.nixos.org/wiki/Wayland#Electron_and_Chromium
    sessionVariables.NIXOS_OZONE_WL = "1";
  };

  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-color-emoji
    font-awesome
    # Icon glyphs (brightness, volume, network, ...) used by bars and
    # notifications; a plain square means the font is missing.
    nerd-fonts.symbols-only
  ];

  # Dark mode, enforced system-wide: the freedesktop color-scheme drives GTK4
  # and libadwaita apps (and their window decorations, including the default
  # title bars niri otherwise shows in white); the legacy GTK3 settings and
  # Qt platform theme cover older toolkits.
  programs.dconf = {
    enable = true;
    profiles.user.databases = [
      {
        settings."org/gnome/desktop/interface" = {
          color-scheme = "prefer-dark";
          gtk-theme = "Adwaita-dark";
          icon-theme = "Adwaita";
        };
      }
    ];
  };

  qt = {
    enable = true;
    platformTheme = "gnome";
    style = "adwaita-dark";
  };
}
