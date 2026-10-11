{
  lib,
  config,
  ...
}:
{
  # Child tests (e.g. workstation/sway) import this module and contribute
  # extra script fragments and node configuration through `defaults`, so
  # their checks run everything defined here plus their own additions.
  options.testScriptFragments = lib.mkOption {
    type = lib.types.listOf (lib.types.functionTo lib.types.str);
    default = [ ];
    description = ''
      Functions from `{ nodes }` to test script text. Definitions from all
      imported test modules are concatenated in order.
    '';
  };

  config = {
    nodes.workstation = {
      imports = [
        ../../modules/roles/workstation
        ../../modules/apps/firefox
      ];
      virtualisation.graphics = true;
      services.pipewire.systemWide = true;
      systemd.services.pipewire.wantedBy = [ "multi-user.target" ];
      users.users.alice = {
        isNormalUser = true;
        extraGroups = [
          "wheel"
          "video"
          "audio"
          "input"
        ];
      };
      services.getty.autologinUser = "alice";
    };

    testScriptFragments = [
      (_: ''
        workstation.start()

        workstation.wait_for_unit("pipewire.service")
        workstation.succeed("systemctl cat rtkit-daemon.service | grep -q Realtime")

        workstation.succeed("test -f /etc/firefox/policies/policies.json")
        workstation.succeed("grep -q bitwarden /etc/firefox/policies/policies.json")
        workstation.succeed("grep -q 'uBlock0@raymondhill.net' /etc/firefox/policies/policies.json")

        workstation.succeed("grep -q 'symlinks = false' /etc/gitconfig")
        workstation.succeed("grep -q 'fsckobjects = true' /etc/gitconfig")

        workstation.succeed("[[ $(cat /proc/sys/kernel/yama/ptrace_scope) == 2 ]]")

        workstation.wait_for_unit("getty@tty1.service")
        workstation.screenshot("console")
      '')
    ];

    testScript =
      { nodes, ... }:
      lib.concatStringsSep "\n" (map (fragment: fragment { inherit nodes; }) config.testScriptFragments);
  };
}
