{
  networking = {
    wireless.iwd = {
      enable = true;
      settings = {
        General = {
          EnableNetworkConfiguration = false; # iwd can hand over to systemd-networkd
        };
        Settings = {
          AutoConnect = true;
        };
      };
    };
  };

  systemd.network = {
    networks."30-wlan-dhcp" = {
      # match any wlan station interface, regardless of its name
      matchConfig.Type = "wlan";
      networkConfig.DHCP = "yes";
      # optional: you can set DHCP client behavior
      dhcpConfig.UseDNS = true;
      dhcpConfig.UseRoutes = true;
      # wifi is not always connected and not required to be online
      linkConfig.RequiredForOnline = "no";
    };
  };
}
