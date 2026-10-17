{
  self,
  inputs,
  ...
}:
{
  perSystem =
    {
      pkgs,
      ...
    }:
    let
      # srvos-style raw usage: `import ./.` with no flake machinery
      rawImport = import ../.;

      # normal flake usage: a consumer's `inputs.infra` is `self`
      normalFlake = self.nixosModules;

      # flake-parts usage: a consumer importing `inputs.infra.flakeModules.default`
      partsConsumer =
        inputs.flake-parts.lib.mkFlake
          {
            self = {
              outputs = _: { };
              rev = "0000000000000000000000000000000000000000";
              shortRev = "0000000";
              sourceInfo.rev = "0000000000000000000000000000000000000000";
            };
            inputs = {
              inherit (inputs) flake-parts;
              infra = self;
            };
          }
          {
            imports = [ self.flakeModules.default ];
          };

      # flake-parts manual usage: a consumer importing individual flakeModules.
      # This consumer must satisfy each module's contract: same-named inputs
      # (nixpkgs, treefmt-nix, srvos) and a self that provides nixosModules
      # for the tests module. Our own flake satisfies all of that, so it
      # stands in for the consumer here.
      partsManual =
        inputs.flake-parts.lib.mkFlake
          {
            inherit self;
            inputs = {
              inherit (inputs)
                flake-parts
                nixpkgs
                treefmt-nix
                srvos
                ;
              infra = self;
            };
          }
          {
            systems = [ "x86_64-linux" ];
            imports = [
              self.flakeModules.checks
              self.flakeModules.devshells
              self.flakeModules.formatters
              self.flakeModules.tests
            ];
          };

      assertions =
        assert
          normalFlake ? default
          && normalFlake ? "roles/workstation"
          && normalFlake ? "roles/workstation/sway"
          && normalFlake ? "roles/workstation/niri"
          && normalFlake ? "roles/server";
        assert rawImport.nixosModules ? default;
        assert
          partsConsumer.nixosModules ? default
          && partsConsumer.nixosModules ? "roles/workstation/sway"
          && partsConsumer.nixosModules ? "roles/workstation/niri";
        assert partsManual.checks.x86_64-linux ? lint;
        assert partsManual.checks.x86_64-linux ? workstation-sway;
        assert partsManual.checks.x86_64-linux ? workstation-niri;
        assert partsManual.devShells.x86_64-linux ? nix;
        assert partsManual.devShells.x86_64-linux ? default;
        assert partsManual.formatter ? x86_64-linux;
        "ok";
    in
    {
      checks = {
        # Linting with statix
        lint = pkgs.stdenv.mkDerivation {
          name = "lint";
          src = self;
          buildInputs = [ pkgs.statix ];
          buildPhase = ''
            statix check .
          '';
          installPhase = "touch $out";
        };

        # Evaluates the three importability paths at flake-eval time; the
        # assertions run while `nix flake check` evaluates this check.
        importable = pkgs.runCommand "infra-importable" { inherit assertions; } ''
          echo "$assertions" > $out
        '';
      };
    };
}
