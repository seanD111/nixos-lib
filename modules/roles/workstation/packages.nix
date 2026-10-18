{ pkgs, ... }:
{
  programs = {
    direnv.enable = true;
  };
  environment.systemPackages = with pkgs; [
    bitwarden-cli
    gimp

    keepassxc
    libarchive
    nmap
    obsidian
    signal-desktop
    thunderbird-latest
    remmina
    vlc
  ];
}
