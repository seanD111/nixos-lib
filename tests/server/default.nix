{
  lib,
  config,
  ...
}:
{
  options.testScriptFragments = lib.mkOption {
    type = lib.types.listOf (lib.types.functionTo lib.types.str);
    default = [ ];
    description = ''
      Functions from `{ nodes }` to test script text. Definitions from all
      imported test modules are concatenated in order.
    '';
  };

  config = {
    nodes.server = {
      imports = [ ../../modules/roles/server ];
    };

    testScriptFragments = [
      (_: ''
        server.start()
        server.wait_for_unit("sshd.service")

        server.succeed("sshd -T | grep -qi 'permitrootlogin no'")
        server.succeed("grep -q 'authorized_keys.d' /etc/ssh/sshd_config")

        server.succeed("systemctl is-active fail2ban.service")

        server.succeed("nft list ruleset | grep -q 'policy drop'")

        server.succeed("[[ $(cat /proc/sys/kernel/sysrq) == 0 ]]")
        server.succeed("[[ $(cat /proc/sys/kernel/io_uring_disabled) == 2 ]]")
        server.succeed("[[ $(cat /proc/sys/kernel/kptr_restrict) == 2 ]]")
        server.succeed("[[ $(cat /proc/sys/kernel/dmesg_restrict) == 1 ]]")
        server.succeed("[[ $(cat /proc/sys/net/ipv4/tcp_syncookies) == 1 ]]")

        server.succeed("grep -q 'symlinks = false' /etc/gitconfig")
        server.succeed("grep -q 'fsckobjects = true' /etc/gitconfig")

        server.fail("systemctl is-enabled bluetooth.service")
        server.fail("systemctl is-enabled pipewire.service")
      '')
    ];

    testScript =
      { nodes, ... }:
      lib.concatStringsSep "\n" (map (fragment: fragment { inherit nodes; }) config.testScriptFragments);
  };
}
