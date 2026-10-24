{ pkgs, ... }:
let
  # Palette: tokyonight-storm, matching foot's bundled theme of the same name.
  # https://github.com/folke/tokyonight.nvim (storm variant)
  colors = {
    bg = "24283b";
    fg = "c0caf5";
    accent = "7aa2f7";
    selection-bg = "2f334d";
  };
in
{
  # Common dark theming shared by every graphical Wayland session. Each
  # self-drawing tool (foot, fuzzel, ...) gets its colors from the same
  # palette so everything reads as one dark theme.

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

  # GTK3 apps can't read dconf on Wayland; the XDG fallback file covers them.
  environment = {
    etc."xdg/gtk-3.0/settings.ini".text = ''
      [Settings]
      gtk-theme-name = Adwaita-dark
      gtk-application-prefer-dark-theme = true
    '';

    systemPackages = [ pkgs.fuzzel ];

    # fuzzel has no NixOS module and ships no themes; write the shared palette
    # directly into its XDG config.
    etc."xdg/fuzzel/fuzzel.ini".text = ''
      [colors]
      background=${colors.bg}ff
      text=${colors.fg}ff
      match=${colors.accent}ff
      selection=${colors.selection-bg}ff
      selection-text=${colors.fg}ff
      selection-match=${colors.accent}ff
      border=${colors.accent}ff

      [border]
      width=2
    '';
  };

  qt = {
    enable = true;
    platformTheme = "gnome";
    style = "adwaita-dark";
  };

  programs.foot = {
    enable = true;
    settings = {
      main.include = [ "${pkgs.foot.themes}/share/foot/themes/tokyonight-storm" ];
    };
  };
}
