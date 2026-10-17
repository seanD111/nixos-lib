{
  nodes.workstation =
    {
      self,
      lib,
      pkgs,
      config,
      ...
    }:
    {
      imports = [
        self.nixosModules."roles/workstation/niri"
        self.nixosModules."hardware/bluetooth"
      ];

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

      # greetd conflicts with the getty autologin this test relies on; the
      # test exercises niri and the cheat sheet, not the display manager.
      services.greetd.enable = lib.mkForce false;

      # Upstream niri refuses software EGL renderers on its TTY backend, and
      # the VM's plain virtio-gpu only offers llvmpipe (the VM-test QEMU has
      # no virgl). So the test runs niri nested inside sway, which renders
      # itself with the software pixman renderer: with WAYLAND_DISPLAY set,
      # niri selects its winit (nested) backend, which accepts llvmpipe. That
      # yields a real rendered niri output to screenshot, without patching
      # niri or needing a host GPU (CI runners have neither).
      programs.sway.enable = true;

      # Software-render sway into the virtio-gpu dumb buffers; niri ignores
      # wlroots variables.
      environment.variables.WLR_RENDERER = "pixman";

      # Run niri as the systemd user service a real session uses: the
      # packaged unit binds graphical-session.target, bringing the session
      # (and waybar with it) up like niri-session does. ExecStart drops
      # --session because that flag removes WAYLAND_DISPLAY to force the tty
      # backend; here niri must stay nested inside sway.
      systemd.user.services.niri.serviceConfig.ExecStart = [
        ""
        "${pkgs.niri}/bin/niri"
      ];

      # waybar's unit has Requisite=graphical-session.target and, left to the
      # target's wants, would start with the parent's socket imported into
      # the user manager and attach to sway. The test imports niri's sockets
      # first and starts it explicitly, so the bar lands inside niri.
      systemd.user.services.waybar.wantedBy = lib.mkForce [ ];

      # A config.d drop-in fragment, included through the generated include
      # lines in /etc/niri/config.kdl; this exercises the drop-in mechanism
      # that also wires in the background. It configures Virtual-1, which is
      # the parent sway display here (harmlessly ignored by nested niri).
      environment.etc."niri/config.d/20-test-output.kdl".text = ''
        output "Virtual-1" {
            mode "${toString config.services.niri-cheatsheet.width}x${toString config.services.niri-cheatsheet.height}"
        }
      '';

      programs.bash.loginShellInit = ''
        if [ "$(tty)" = "/dev/tty1" ]; then
          mkdir -p ~/.config/sway
          # 1:1 display so the nested niri window can fill the whole screen.
          echo 'output Virtual-1 resolution ${toString config.services.niri-cheatsheet.width}x${toString config.services.niri-cheatsheet.height}' > ~/.config/sway/config
          # The nested niri window has app_id "niri"; make it fill the display
          # so niri's output covers the resolution.
          echo 'for_window [app_id="niri"] fullscreen enable' >> ~/.config/sway/config
          sway --validate
          sway >/tmp/sway.log 2>&1 &
          # With WAYLAND_DISPLAY set, niri runs nested (winit backend) inside
          # sway instead of grabbing the tty; unset, it would start on the tty
          # and steal the DRM master from sway. The system config from
          # /etc/niri/config.kdl drives it, so the config.d drop-ins (and the
          # swaybg cheat sheet) apply to it too.
          niri validate
          while [ ! -S /run/user/$(id -u)/wayland-1 ]; do sleep 0.2; done
          # Hand the parent session socket and PATH to the user manager (the
          # niri unit intentionally has no default PATH so sessions can
          # import one) and start niri as the user service.
          WAYLAND_DISPLAY=wayland-1 systemctl --user import-environment WAYLAND_DISPLAY PATH
          systemctl --user start niri.service
        fi
      '';

      virtualisation.memorySize = 2048;
      virtualisation.qemu.options = [ "-vga none -device virtio-gpu-pci" ];
    };

  testScript =
    { nodes, ... }:
    let
      cheatsheet = nodes.workstation.services.niri-cheatsheet;
      width = toString cheatsheet.width;
      height = toString cheatsheet.height;
      conf = "/etc/niri/config.d/10-background.kdl";
      confText = nodes.workstation.environment.etc."niri/config.d/10-background.kdl".text;
      mainConfig = "/etc/niri/config.kdl";
      png = builtins.head (
        builtins.match "spawn-at-startup \"swaybg\" \"-i\" \"([^\"]+)\" \"-m\" \"fill\"\n?" confText
      );
    in
    ''
      import json
      import shlex

      q = shlex.quote

      def session_run(command):
          """Run a command as alice inside the niri session environment.

          Wayland clients resolve the compositor via XDG_RUNTIME_DIR and
          WAYLAND_DISPLAY; niri msg additionally via NIRI_SOCKET. Both socket
          names are chosen by niri at startup, so the test discovers them from
          the runtime directory instead of hardcoding them.
          """
          env = (
              f"XDG_RUNTIME_DIR=/run/user/{uid} "
              f"WAYLAND_DISPLAY={wayland} "
              f"NIRI_SOCKET={niri_socket}"
          )
          shell = q(f"{env} {command}")
          return workstation.succeed(f"su - alice -c {shell}")

      def niri_msg(*args):
          return json.loads(session_run(f"niri msg --json {q(' '.join(args))}"))

      def assert_png_size(path):
          # PNG IHDR width/height live at bytes 16-24, big-endian.
          workstation.succeed(
              "od -An -tu4 -j 16 -N 8 --endian=big "
              + shlex.quote(path)
              + " | grep -qE '${width} +${height}'"
          )

      workstation.start()
      uid = workstation.succeed("id -u alice").strip()

      workstation.succeed("systemctl is-enabled bluetooth.service")
      workstation.succeed("grep -q 'AutoEnable=false' /etc/bluetooth/main.conf")
      workstation.succeed("grep -q 'PairableTimeout=30' /etc/bluetooth/main.conf")
      workstation.wait_for_unit("multi-user.target")

      # The system config must exist with the generated include for the
      # background fragment, and the fragment must reference the exact PNG the
      # module rendered; that PNG must be a PNG of the declared resolution
      # (IHDR width/height at bytes 16-24).
      workstation.succeed("test -f ${conf}")
      workstation.succeed("test -f ${mainConfig}")
      workstation.succeed(
          "grep -qF 'include \"/etc/niri/config.d/10-background.kdl\"' ${mainConfig}"
      )
      workstation.succeed(
          "grep -qF 'spawn-at-startup \"swaybg\" \"-i\" \"${png}\" \"-m\" \"fill\"' ${conf}"
      )
      workstation.succeed("test -f ${png}")
      assert_png_size("${png}")

      # Wait for the parent sway session.
      workstation.wait_for_file(f"/run/user/{uid}/wayland-1")

      # Wait for niri's IPC socket; on timeout, surface the parent
      # compositor log, since a dead sway is the most likely cause.
      def wait_for_niri_sockets():
          try:
              workstation.wait_until_succeeds(
                  f"ls /run/user/{uid}/niri.*.sock | head -1", timeout=120
              )
          except Exception:
              print(workstation.execute("cat /tmp/sway.log 2>&1")[1])
              print(workstation.execute("pgrep -a sway; pgrep -a niri")[1])
              raise

      wait_for_niri_sockets()
      niri_socket = workstation.succeed(f"ls /run/user/{uid}/niri.*.sock | head -1").strip()
      wayland = niri_socket.rsplit("/", 1)[1].removeprefix("niri.").rsplit(".", 2)[0]

      # niri (winit backend) must not have taken the seat away from sway.
      workstation.wait_until_succeeds("pgrep -x sway")

      # The nested niri is a fully working compositor: it serves IPC and
      # clients and has a rendered output (see the sway nesting above).
      windows = niri_msg("windows")
      assert isinstance(windows, list), "niri IPC did not return a window list"

      # Bring up waybar: niri's systemd service already bound
      # graphical-session.target, so waybar's Requisite is satisfied once
      # niri's sockets are imported into the user manager environment.
      session_run("systemctl --user import-environment WAYLAND_DISPLAY NIRI_SOCKET")
      session_run("systemctl --user start waybar")

      def check_waybar_layer(_elapsed):
          layers = niri_msg("layers")
          return any(layer.get("namespace") == "waybar" for layer in layers)

      retry(check_waybar_layer, timeout_seconds=60)

      # Open a terminal like the sway test does, so the screenshots show a
      # real desktop rather than just the background.
      session_run("niri msg action spawn -- foot")

      def check_foot_window(_elapsed):
          return any(window.get("app_id") == "foot" for window in niri_msg("windows"))

      retry(check_foot_window, timeout_seconds=60)
      workstation.sleep(2)

      # The sway parent fullscreens the nested niri window, so niri's output
      # grows to the configured display resolution; wait for the output to
      # appear and for the resize to settle before capturing.
      def niri_output_size():
          for out in niri_msg("outputs").values():
              if out["current_mode"] is not None:
                  mode = out["modes"][out["current_mode"]]
                  return [mode["width"], mode["height"]]
          return None

      def check_output_size(_elapsed):
          return niri_output_size() == [${width}, ${height}]

      retry(check_output_size, timeout_seconds=120)

      # Capture the desktop from inside the guest through niri's own IPC
      # screenshot action: this shows the real niri output (cheat-sheet
      # background, waybar, foot) regardless of the emulated display.
      session_run("niri msg action screenshot-screen --path /tmp/niri-screenshot.png")
      # niri encodes and writes the PNG asynchronously.
      workstation.wait_until_succeeds("test -f /tmp/niri-screenshot.png", timeout=60)
      # The capture must be a PNG of the rendered output size, which proves
      # niri rendered its output.
      assert_png_size("/tmp/niri-screenshot.png")
      workstation.copy_from_machine("/tmp/niri-screenshot.png", "niri-screenshot")

      # Also capture the emulated display itself, as the sway test does: the
      # nested niri window filling the screen with the cheat sheet.
      workstation.screenshot("niri-display-screenshot")

      # Export the rendered cheat sheet and the composed system config as
      # additional artifacts. The files are dereferenced first: /etc entries
      # are symlinks and the driver's copy does not follow them.
      workstation.succeed("cp -L ${png} /tmp/cheatsheet.png")
      workstation.succeed("cp -L ${mainConfig} /tmp/config.kdl")
      workstation.copy_from_machine("/tmp/cheatsheet.png", "cheatsheet")
      workstation.copy_from_machine("/tmp/config.kdl", "config")
    '';
}
