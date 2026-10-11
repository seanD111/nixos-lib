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

  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --sessions /run/current-system/sw/share/wayland-sessions";
      user = "greeter";
    };
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
