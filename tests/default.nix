{
  self,
  inputs,
  lib,
  ...
}:
{
  # Each test file owns the complete scenario: which modules its node imports
  # (via `self.nixosModules`, the library's public interface) and the
  # testScript, so a single file is the source of truth for its test. The
  # runner only supplies plumbing shared by all tests. `self` and `inputs`
  # reach the test files' node modules through node.specialArgs; the library
  # modules require them as module arguments.
  perSystem =
    { system, ... }:
    lib.optionalAttrs
      (lib.elem system [
        "x86_64-linux"
        "aarch64-linux"
      ])
      {
        checks =
          lib.mapAttrs
            (
              name: file:
              inputs.nixpkgs.lib.nixos.runTest {
                imports = [ file ];
                name = "infra-${name}";
                hostPkgs = inputs.nixpkgs.legacyPackages.${system};
                node.specialArgs = { inherit inputs self; };
                defaults = {
                  system.stateVersion = "26.05";
                  users.allowNoPasswordLogin = true;
                };
              }
            )
            {
              server = ./server.nix;
              workstation = ./workstation.nix;
              workstation-sway = ./sway.nix;
              workstation-niri = ./niri.nix;
            };
      };
}
