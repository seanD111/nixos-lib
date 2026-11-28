{ inputs, lib, ... }:
{
  imports = [
    inputs.srvos.nixosModules.server
    ./..
    ./documentation.nix
    ./networking.nix
    ./openssh.nix
  ];

  time.timeZone = lib.mkForce "UTC";

  # Servers don't need a pinned nixpkgs in the system registry/NIX_PATH.
  nixpkgs.flake.setFlakeRegistry = false;
  nixpkgs.flake.setNixPath = false;

  # Keep nixos-rebuild, but skip installer-only tooling.
  system.tools.nixos-generate-config.enable = false;
  system.tools.nixos-install.enable = false;
  system.tools.nixos-enter.enable = false;
  system.tools.nixos-build-vms.enable = false;

  # restic only needs S3/SFTP here; drop its optional rclone backend.
  nixpkgs.overlays = [
    (final: prev: {
      restic = prev.restic.override { rclone = prev.emptyDirectory; };
    })
  ];
}
