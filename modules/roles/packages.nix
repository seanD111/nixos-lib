{ pkgs, lib, ... }:
{
  environment = {
    variables.EDITOR = "vim";
    defaultPackages = lib.mkForce [ ];
    systemPackages = with pkgs; [
      age
      b3sum
      dnsutils
      curl
      fd
      htop
      jq
      killall
      openssl
      qrtool
      restic
      rsync
      sops
      tcpdump
      traceroute
      tree
      vim
      wireguard-tools
      wget
      yq-go
      zip
    ];
  };
}
