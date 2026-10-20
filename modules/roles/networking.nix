{ lib, ... }:
{
  networking = {
    useDHCP = lib.mkDefault false;
    nftables.enable = lib.mkDefault true;
    firewall.enable = lib.mkDefault true;
  };

  services.resolved.enable = true;

  systemd.network.enable = lib.mkDefault true;

  systemd.network.networks."90-fallback-dhcp" = {
    matchConfig.Name = "*";
    networkConfig.DHCP = "yes";
    dhcpConfig.UseDNS = true;
    dhcpConfig.UseRoutes = true;
  };

  boot.initrd.systemd.network.networks."91-fallback-dhcp-initrd" = {
    matchConfig.Name = "*";
    networkConfig.DHCP = "yes";
    dhcpConfig.UseDNS = true;
    dhcpConfig.UseRoutes = true;
  };
}
