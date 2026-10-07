{
  name = "infra-workstation-sway";
  defaults.system.stateVersion = "26.05";
  defaults.users.allowNoPasswordLogin = true;

  nodes.workstation = { config, ... }: {
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

    programs.bash.loginShellInit = ''
      if [ "$(tty)" = "/dev/tty1" ]; then
        mkdir -p ~/.config/sway
        # waybar is started by the user systemd graphical-session.target; drop
        # the stock swaybar block but keep the config.d include that wires the
        # systemd session.
        sed '/^bar {/,/^}/d' /etc/sway/config > ~/.config/sway/config
        # 1:1 display so the cheat-sheet background is fully visible
        echo 'output Virtual-1 resolution ${toString config.services.sway-cheatsheet.width}x${toString config.services.sway-cheatsheet.height}' >> ~/.config/sway/config
        sway --validate
        sway
      fi
    '';

    environment.variables = {
      SWAYSOCK = "/tmp/sway-ipc.sock";
      WLR_RENDERER = "pixman";
    };

    virtualisation.qemu.options = [ "-vga none -device virtio-gpu-pci" ];
  };

  testScript =
    { nodes, ... }:
    let
      cheatsheet = nodes.workstation.config.services.sway-cheatsheet;
      width = toString cheatsheet.width;
      height = toString cheatsheet.height;
      conf = "/etc/sway/config.d/10-background.conf";
      confText = nodes.workstation.environment.etc."sway/config.d/10-background.conf".text;
      png = builtins.head (builtins.match "output \\* bg ([^ ]+) fill\n?" confText);
    in
    ''
      import json
      import shlex

      q = shlex.quote

      def session_run(command, succeed=True):
          """Run a command as alice inside the sway session environment.

          Wayland clients resolve the compositor via XDG_RUNTIME_DIR and
          WAYLAND_DISPLAY; swaymsg additionally via SWAYSOCK. A login shell
          (`su - alice`) would strip all of these, so the helper injects them.
          """
          env = (
              f"XDG_RUNTIME_DIR=/run/user/{uid} "
              "WAYLAND_DISPLAY=wayland-1 "
              "SWAYSOCK=/tmp/sway-ipc.sock"
          )
          shell = q(f"{env} {command}")
          runner = workstation.succeed if succeed else workstation.execute
          return runner(f"su - alice -c {shell}")

      def swaymsg(command="", type="command"):
          return json.loads(session_run(f"swaymsg -t {q(type)} -- {q(command)}"))

      def walk(tree):
          yield tree
          for group in ("nodes", "floating_nodes"):
              for node in tree.get(group, []):
                  yield from walk(node)

      def wait_for_window(pattern):
          def check(_):
              return any(
                  pattern in (node.get("name") or "")
                  or pattern in (node.get("app_id") or "")
                  for node in walk(swaymsg(type="get_tree"))
              )

          retry(check)

      workstation.start()
      uid = workstation.succeed("id -u alice").strip()

      workstation.succeed("systemctl is-enabled bluetooth.service")
      workstation.succeed("grep -q 'AutoEnable=false' /etc/bluetooth/main.conf")
      workstation.succeed("grep -q 'PairableTimeout=30' /etc/bluetooth/main.conf")
      workstation.wait_for_unit("multi-user.target")
      workstation.wait_for_file(f"/run/user/{uid}/wayland-1")
      workstation.wait_for_file("/tmp/sway-ipc.sock")

      # The cheat-sheet background must be wired through sway/config.d and must
      # reference the exact PNG the module rendered; that PNG must be a PNG of
      # the declared resolution (IHDR width/height at bytes 16-24).
      workstation.succeed("test -f ${conf}")
      workstation.succeed("grep -qF 'output * bg ${png} fill' ${conf}")
      workstation.succeed("test -f ${png}")
      workstation.succeed(
          "od -An -tu4 -j 16 -N 8 --endian=big ${png} | grep -qE '${width} +${height}'"
      )

      tree = swaymsg(type="get_tree")
      assert tree["type"] == "root", "sway IPC is not a root tree"
      workstation.wait_until_succeeds("pgrep waybar")

      # waybar takes ~2.5s from process spawn (pgrep success) to map its layer
      # surface; "Bar configured" in the journal marks the first rendered frame.
      workstation.wait_until_succeeds("journalctl --no-pager | grep -qF 'Bar configured'")
      workstation.sleep(2)

      workstation.screenshot("waybar-screenshot")
      swaymsg("exec foot")
      wait_for_window("foot")
      workstation.sleep(2)

      # Capture the compositor framebuffer from inside the guest: this shows
      # the real desktop (background, bar, windows) regardless of the emulated
      # display state.
      # session_run("grim /tmp/sway-grim.png")
      # workstation.copy_from_machine("/tmp/sway-grim.png", "")
      workstation.screenshot("sway-screenshot")
    '';
}
