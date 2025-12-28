{
  description = "Zerobyte - Self-hosted backup automation and management (Nix flake)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    bun2nix = {
      url = "github:nix-community/bun2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zerobyte-src = {
      url = "github:nicotsx/zerobyte/v0.20.0";
      flake = false;
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      bun2nix,
      zerobyte-src,
      treefmt-nix,
    }:
    let
      # Systems for packages and devShells (cross-platform)
      allSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      # Linux-only systems for NixOS module and VM tests
      linuxSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      # Shared configuration
      # NOTE: When updating zerobyte, change BOTH:
      #   1. zerobyte-src URL tag (above)
      #   2. version string (below)
      # Then run: nix flake update zerobyte-src && nix develop -c update-bun-nix
      config = {
        inherit zerobyte-src;
        version = "0.20.0";
        patches = [ ./patches/0001-add-port-and-migrations-path-config.patch ];
        bunNix = ./bun.nix;
      };

    in
    flake-utils.lib.eachSystem allSystems (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ bun2nix.overlays.default ];
        };

        # Import package definitions
        packages = import ./nix/packages {
          inherit pkgs system config;
          inherit (pkgs) lib;
          bun2nixPkgs = bun2nix.packages.${system};
        };

        # Configure treefmt for nix formatting
        treefmtEval = treefmt-nix.lib.evalModule pkgs {
          projectRootFile = "flake.nix";
          programs.nixfmt.enable = true;
        };

        isLinux = builtins.elem system linuxSystems;

      in
      {
        packages = {
          inherit (packages) zerobyte shoutrrr;
          default = packages.zerobyte;
        };

        devShells.default = import ./nix/dev-shell.nix {
          inherit pkgs system;
          inherit (packages) shoutrrr;
          bun2nixPkgs = bun2nix.packages.${system};
        };

        # Nix formatter (via treefmt)
        formatter = treefmtEval.config.build.wrapper;

        # Checks: formatting (all systems) + integration (Linux only)
        checks = {
          formatting = treefmtEval.config.build.check self;
        }
        // (
          if isLinux then
            {
              integration = import ./nix/tests/integration.nix {
                inherit pkgs self;
              };
            }
          else
            { }
        );
      }
    )
    // {
      # Overlay for use in other flakes (only adds attrs on supported systems)
      overlays.default =
        final: prev:
        let
          packages = self.packages.${final.system} or null;
        in
        # Only add packages if system is supported (avoids null violating types.package)
        if packages != null then
          {
            inherit (packages) zerobyte shoutrrr;
          }
        else
          { };

      # NixOS module
      nixosModules.default = import ./nix/modules/nixos.nix { inherit self; };

      # nix-darwin module (macOS)
      darwinModules.default = import ./nix/modules/darwin.nix { inherit self; };
    };
}
