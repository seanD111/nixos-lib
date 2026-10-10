{ flake-parts-lib, ... }: {
  imports = [
    ./nix.nix
    ./maker.nix
    ./laser-cut.nix
  ];

  options.perSystem = flake-parts-lib.mkPerSystemOption (
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      jsonFormat = pkgs.formats.json { };
    in
    {
      options.devshells = lib.mkOption {
        description = ''
          Devshell definitions, each exposed as a `nix develop .#<name>` shell.

          Every shell bundles a VSCodium wrapper that ships the shell's
          extensions and settings. Shells are pluggable: any module can
          contribute to a shell's `packages`, `extensions`, `settings` and
          `enterShell` (they merge across modules), and a new shell can build
          on another, e.g. `devshells.go.packages = config.devshells.nix.packages ++ [ ... ]`.
        '';
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              packages = lib.mkOption {
                type = lib.types.listOf lib.types.package;
                default = [ ];
                description = "Packages available in the shell (and in VSCodium terminals).";
              };
              extensions = lib.mkOption {
                type = lib.types.listOf lib.types.package;
                default = [ ];
                description = "VSCodium extension derivations, typically from `pkgs.vscode-extensions`.";
              };
              settings = lib.mkOption {
                inherit (jsonFormat) type;
                default = { };
                description = "Contents written to the bundled VSCodium's `settings.json`. Merges across modules.";
              };
              enterShell = lib.mkOption {
                type = lib.types.lines;
                default = "";
                description = "Extra commands run on shell entry. Merges across modules.";
              };
              autoOpen = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Open the bundled VSCodium on shell entry (skipped inside VSCodium, or when `AUTO_OPEN_EDITOR=0`).";
              };
            };
          }
        );
      };

      options.defaultShell = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Name of the devshell to also expose as `.#default`, so bare
          `nix develop` enters it. Must match a key of `devshells`.
        '';
      };

      config.devShells =
        lib.mapAttrs (
          name: cfg:
          let
            settingsJson = jsonFormat.generate "settings.json" cfg.settings;
            vscodium = pkgs.vscode-with-extensions.override {
              vscode = pkgs.vscodium;
              vscodeExtensions = cfg.extensions;
            };
            codium = pkgs.writeShellScriptBin "codium" ''
              dir="$PWD"
              while [ ! -f "$dir/flake.nix" ] && [ "$dir" != "/" ]; do
                dir="$(dirname "$dir")"
              done
              if [ "$#" -eq 0 ]; then
                set -- "$dir"
              fi
              hash="$(printf %s "$dir" | sha1sum | cut -c1-8)"
              data="''${XDG_DATA_HOME:-$HOME/.local/share}/vscodium-devshells/${name}-$hash"
              mkdir -p "$data/User"
              # devshell settings always take precedence: the module's
              # `settings` is the single source of truth for this profile
              rm -f "$data/User/settings.json"
              install -m 644 ${settingsJson} "$data/User/settings.json"
              # CODEDIUM_NO_SANDBOX=1 (set on the affected machine) drops the
              # Chromium sandbox — last-resort for hosts where it cannot
              # initialize (Ubuntu 24.04 AppArmor userns restriction, containers).
              # prefer the targeted fixes first on an affected host: (sysctl kernel.apparmor_restrict_unprivileged_userns=0);
              no_sandbox="''${CODEDIUM_NO_SANDBOX:+--no-sandbox}"
              exec ${vscodium}/bin/codium --user-data-dir "$data" ''$no_sandbox "$@"
            '';
          in
          pkgs.mkShell {
            name = "devshell-${name}";
            # Readline-enabled bash first on PATH, so nested `nix develop`, editor
            # terminals and anything resolving `bash` from this environment gets
            # the interactive build (arrow keys, prompt escapes).
            packages = [ pkgs.bashInteractive ] ++ cfg.packages ++ [ codium ];
            SHELL = "${pkgs.bashInteractive}/bin/bash";
            shellHook = ''
              __devshell_prompt() {
                PS1='[${name}:\w]\$ '
              }
              PROMPT_COMMAND='command -v __devshell_prompt >/dev/null && __devshell_prompt'
              export PROMPT_COMMAND
              export DEVSHELL_NAME="${name}"
              ${lib.optionalString cfg.autoOpen ''
                if [ "''${AUTO_OPEN_EDITOR:-1}" = "1" ] && [ "''${TERM_PROGRAM:-}" != "vscode" ]; then
                  codium >/dev/null 2>&1 &
                fi
              ''}
            ''
            + cfg.enterShell;
          }
        ) config.devshells
        // lib.optionalAttrs (config.defaultShell != null && config.devshells ? ${config.defaultShell}) {
          default = config.devShells.${config.defaultShell};
        };
    }
  );
}
