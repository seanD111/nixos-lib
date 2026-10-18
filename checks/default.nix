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
      # (nixpkgs, treefmt-nix, srvos) and a self that provides nixosModules.
      # The NixOS tests module is not exported as a flakeModule; it is
      # imported here by path, which is the deliberate opt-in a consumer
      # would perform. Our own flake satisfies all of that, so it stands in
      # for the consumer here.
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
              ../tests
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
        assert partsManual.hydraJobs.x86_64-linux ? workstation-sway;
        assert partsManual.hydraJobs.x86_64-linux ? workstation-niri;
        # the VM tests are opt-in: importing the flakeModules must not add
        # them to a consumer's checks
        assert
          !(partsManual.checks.x86_64-linux ? workstation)
          && !(partsManual.checks.x86_64-linux ? workstation-sway)
          && !(partsManual.checks.x86_64-linux ? workstation-niri)
          && !(partsManual.checks.x86_64-linux ? server);
        assert partsManual.devShells.x86_64-linux ? nix;
        assert partsManual.devShells.x86_64-linux ? default;
        assert partsManual.formatter ? x86_64-linux;

        # Every role must evaluate on the NixOS systems the flake supports;
        # forcing each system's toplevel derivation path catches packages
        # that are unavailable or broken on a platform (e.g. discord used to
        # make the workstation role unevaluatable on aarch64-linux).
        assert builtins.all (drvPath: drvPath != "") (
          inputs.nixpkgs.lib.flatten (
            map
              (
                system:
                map
                  (
                    role:
                    (inputs.nixpkgs.lib.nixosSystem {
                      inherit system;
                      modules = [
                        self.nixosModules.${role}
                        # minimal machine wiring so toplevel evaluation
                        # does not trip the boot/fileSystem/password
                        # assertions
                        {
                          fileSystems."/" = {
                            device = "/dev/disk/by-label/nixos";
                            fsType = "ext4";
                          };
                          boot.loader.grub.devices = [ "/dev/vda" ];
                          users.allowNoPasswordLogin = true;
                        }
                      ];
                      # the role modules take the consumer's inputs as a
                      # module argument (e.g. srvos for the server role)
                      specialArgs.inputs = {
                        inherit (inputs) nixpkgs srvos;
                      };
                    }).config.system.build.toplevel.drvPath
                  )
                  [
                    "roles/server"
                    "roles/workstation"
                    "roles/workstation/sway"
                    "roles/workstation/niri"
                  ]
              )
              [
                "x86_64-linux"
                "aarch64-linux"
              ]
          )
        );
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
