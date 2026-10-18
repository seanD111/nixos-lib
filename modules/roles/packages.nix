{ pkgs, lib, ... }:
{
  environment = {
    variables.EDITOR = "vim";
    defaultPackages = lib.mkForce [ ];
    systemPackages = with pkgs; [
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
