{ lib, ... }:
{
  # we also don't want our servers trying multicast dns / service discovery
  services.avahi.enable = lib.mkForce false;

  # Rate-limit new SSH connections per source address. Sources that exceed
  # the limit are blocked for an hour. Runs after the firewall's own chain,
  # so its SSH accept rule does not bypass this check.
  networking.nftables.tables.ssh_hardening = {
    family = "inet";
    content = ''
      set ssh_flood4 {
        type ipv4_addr
        flags dynamic, timeout
        timeout 1h
      }

      set ssh_flood6 {
        type ipv6_addr
        flags dynamic, timeout
        timeout 1h
      }

      chain input {
        type filter hook input priority filter + 10; policy accept;

        tcp dport 22 ct state new ip saddr @ssh_flood4 drop
        tcp dport 22 ct state new ip6 saddr @ssh_flood6 drop

        tcp dport 22 ct state new update @ssh_flood4 { ip saddr limit rate over 5/minute } drop
        tcp dport 22 ct state new update @ssh_flood6 { ip6 saddr limit rate over 5/minute } drop
      }
    '';
  };
}
