{
  inputs,
  lib,
  ...
}:
let
  testsRoot = ./.;

  # Collect one test per directory with a default.nix, mirroring the module
  # tree: nested directories extend their parent (server, workstation,
  # workstation-sway, ...).
  collect =
    prefix: dir:
    let
      entries = builtins.readDir dir;
      subdirs = lib.filterAttrs (_: type: type == "directory") entries;
      hasDefault = (entries."default.nix" or null) == "regular";
      childPrefixes = builtins.mapAttrs (
        name: _: if prefix == "" then name else "${prefix}-${name}"
      ) subdirs;
    in
    (lib.optionalAttrs hasDefault { ${prefix} = dir + "/default.nix"; })
    // builtins.foldl' (acc: name: acc // (collect childPrefixes.${name} (dir + "/${name}"))) { } (
      builtins.attrNames childPrefixes
    );

  tests = lib.foldl' (acc: name: acc // (collect name (testsRoot + "/${name}"))) { } (
    builtins.attrNames (lib.filterAttrs (_: type: type == "directory") (builtins.readDir testsRoot))
  );
in
{
  perSystem =
    { system, ... }:
    lib.optionalAttrs
      (lib.elem system [
        "x86_64-linux"
        "aarch64-linux"
      ])
      {
        checks = builtins.mapAttrs (
          name: path:
          inputs.nixpkgs.lib.nixos.runTest {
            imports = [ path ];
            name = "infra-${name}";
            hostPkgs = inputs.nixpkgs.legacyPackages.${system};
            node.specialArgs = { inherit inputs; };
            defaults.system.stateVersion = "26.05";
            defaults.users.allowNoPasswordLogin = true;
          }
        ) tests;
      };
}
