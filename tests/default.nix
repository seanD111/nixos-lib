{
  self,
  inputs,
  lib,
  ...
}:
{
  # Internal flake-parts module, deliberately NOT exported via
  # flake.flakeModules. It publishes the NixOS VM tests under
  # flake.hydraJobs instead of flake.checks, so the tests are opt-in:
  # `nix flake check` does not build them, and consumers importing this
  # repo's flakeModules do not get them merged into their checks. Run one
  # with e.g. `nix build .#hydraJobs.x86_64-linux.workstation-niri`.
  #
  # The linux systems the flake supports are covered; the roles are verified
  # to evaluate on both by the importable check.
  #
  # Each test file owns the complete scenario: which modules its node
  # imports (via `self.nixosModules`, the library's public interface) and
  # the testScript, so a single file is the source of truth for its test.
  # The runner only supplies plumbing shared by all tests. `self` and
  # `inputs` reach the test files' node modules through node.specialArgs;
  # the library modules require them as module arguments.
  flake.hydraJobs =
    lib.genAttrs
      [
        "x86_64-linux"
        "aarch64-linux"
      ]
      (
        system:
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
          }
      );
}
