{ pkgs, lib, ... }:
{
  environment = {
    variables.EDITOR = "vim";
    defaultPackages = lib.mkForce [ ];
    systemPackages = with pkgs; [
      age
      b3sum
      ipv6calc
      dnsutils
      curl
      fd
      htop
      jq
      killall
      nebula
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
