{
  enableOCR = true;

  nodes.workstation = { self, ... }: {
    imports = [
      self.nixosModules."roles/workstation"
      self.nixosModules."apps/firefox"
    ];
    virtualisation.graphics = true;
    services.pipewire.systemWide = true;
    systemd.services.pipewire.wantedBy = [ "multi-user.target" ];
  };

  testScript = ''
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
    workstation.wait_for_text("login")
    workstation.screenshot("console")
  '';
}
