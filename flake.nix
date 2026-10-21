{
  description = "seanD111's importable NixOS infrastructure library";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    srvos = {
      url = "github:nix-community/srvos";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    let
      # single source of truth for the library shape (srvos-style)
      library = import ./.;

      # reusable flake-parts modules: imported below to activate this
      # flake's own outputs, and exported as flakeModules for consumers
      flakeModules = {
        checks = ./checks;
        devshells = ./devshells;
        formatters = ./formatters;
        nixos-modules = {
          flake.nixosModules = library.nixosModules;
        };
      };

      # internal module that publishes the NixOS VM tests under
      # flake.hydraJobs: activated below, but deliberately not part of
      # flakeModules, so the tests stay opt-in and are neither built by
      # `nix flake check` nor merged into consumers' checks
      nixosTestsModule = ./tests;
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      imports = [
        inputs.flake-parts.flakeModules.flakeModules
      ]
      ++ builtins.attrValues flakeModules
      ++ [ nixosTestsModule ];
      flake.flakeModules = flakeModules // {
        # consumer-safe alias: only the NixOS module wiring
        default = flakeModules.nixos-modules;
      };
    };
}
