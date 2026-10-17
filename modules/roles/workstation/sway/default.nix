{ ... }:
{
  imports = [
    ./..
    ../wayland-session.nix
    ./background.nix
  ];

  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true; # Fix for some GTK apps
  };
}
