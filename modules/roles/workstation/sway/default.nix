{ pkgs, ... }:
{
  imports = [
    ./..
    ./background.nix
  ];

  programs = {
    sway = {
      enable = true;
      wrapperFeatures.gtk = true; # Fix for some GTK apps
    };
    foot.enable = true;
    waybar.enable = true;
  };

  environment.systemPackages = with pkgs; [
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
  ];

  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-color-emoji
    font-awesome
  ];

}
