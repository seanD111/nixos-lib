{ pkgs, ... }:
{
  imports = [
    ./..
    ../wayland-session.nix
    ./background.nix
    ./config.nix
  ];

  programs.niri.enable = true;

  # niri composites no wallpaper itself, so swaybg draws the cheat-sheet from
  # the background fragment; and XWayland support comes from
  # xwayland-satellite, which niri integrates automatically when it is on
  # PATH (sway has both built in).
  # https://wiki.nixos.org/wiki/Niri
  environment.systemPackages = with pkgs; [
    swaybg
    xwayland-satellite
  ];
}
