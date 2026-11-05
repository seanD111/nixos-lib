{ pkgs, ... }:
{
  programs = {
    direnv.enable = true;
  };
  environment.systemPackages = with pkgs; [
    age-plugin-yubikey
    ssh-to-age
    vscodium
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
    vesktop
  ];
}
