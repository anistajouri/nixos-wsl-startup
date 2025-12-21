{
  description = "NixOS configuration";

  # --- INPUTS --------------------------------------------------------------
  # Inputs are the dependencies of your flake. They are other flakes,
  # such as nixpkgs, home-manager, or other repositories containing Nix code.

  # Nixpkgs: The official Nix package repository.
  # We are pinning it to a specific stable release for reproducibility.
  # https://github.com/nixos/nixpkgs#nixpkgs : nixos-25.11 (last stable release)
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

  # Home Manager: Manages user-specific configuration files (dotfiles).
  # This helps in keeping your home directory clean and reproducible.
  # GitHub Repository: https://github.com/nix-community/home-manager
  # Specific Branch: https://github.com/nix-community/home-manager/tree/release-25.11
  inputs.home-manager.url = "github:nix-community/home-manager/release-25.11";
  inputs.home-manager.inputs.nixpkgs.follows = "nixpkgs"; # Ensures home-manager uses the same nixpkgs version.

  # NixOS-WSL: Provides necessary tools and configurations for running NixOS on WSL.
  # https://github.com/nix-community/NixOS-WSL
  inputs.nixos-wsl.url = "github:nix-community/NixOS-WSL";
  inputs.nixos-wsl.inputs.nixpkgs.follows = "nixpkgs";

  # nix-index-database: A database for the `nix-index` tool, which allows you
  # to quickly search for packages that provide a specific command.
  inputs.nix-index-database.url = "github:nix-community/nix-index-database";
  inputs.nix-index-database.inputs.nixpkgs.follows = "nixpkgs";

  # Local input for LVim configuration.
  # For CI builds: comment out the next two lines
  inputs.lvim.url = "/mnt/d/nix/LVim";
  inputs.lvim.flake = true;
  # For CI builds: uncomment the next line to use nixpkgs as dummy input
  #inputs.lvim.follows = "nixpkgs";

  # --- OUTPUTS -------------------------------------------------------------
  # Outputs define what your flake provides, such as NixOS configurations,
  # development shells, packages, etc.
  outputs = inputs:
    with inputs; let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      # Load custom configuration from a JSON file.
      # Uses my_config.json if it exists (local development), otherwise falls back to my_config.json.example (CI/template)
      configFile =
        if builtins.pathExists "${self}/my_config.json"
        then "${self}/my_config.json"
        else "${self}/my_config.json.example";
      my_config = builtins.fromJSON (builtins.readFile configFile);

      # Check if lvim is a real flake with overlays (not just following nixpkgs)
      hasLvim = lvim ? overlays && lvim.overlays ? default;

      # A function to create a nixpkgs instance with specific overlays and config.
      nixpkgsWithOverlays = system: (import nixpkgs rec {
        inherit system;

        config = {
          allowUnfree = true; # Allow proprietary software.
          permittedInsecurePackages = [
            # List any insecure packages you need to use here.
          ];
        };

        # Overlays add or modify packages in nixpkgs.
        # Only include lvim overlay if lvim is a real flake (not following nixpkgs)
        overlays = if hasLvim then [ lvim.overlays.default ] else [ ];
      });

      # Default configuration for home-manager.
      configurationDefaults = args: {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.backupFileExtension = "hm-backup";
        home-manager.extraSpecialArgs = args;
      };

      # Default arguments to pass to modules.
      argDefaults = {
        inherit my_config inputs self nix-index-database hasLvim;
        channels = {
          inherit nixpkgs;
        };
      };

      # A helper function to build a NixOS configuration.
      mkNixosConfiguration = {
        system ? "x86_64-linux",
        hostname,
        username,
        args ? {},
        modules,
      }: let
        specialArgs = argDefaults // {inherit hostname username;} // args;
      in
        nixpkgs.lib.nixosSystem {
          inherit system specialArgs;
          pkgs = nixpkgsWithOverlays system;
          modules =
            [
              (configurationDefaults specialArgs)
              home-manager.nixosModules.home-manager
            ]
            ++ modules;
        };
    in {
      # --- FORMATTER ---------------------------------------------------------
      # Defines a code formatter for this project (e.g., `nix fmt`).
      formatter.${system} = pkgs.alejandra;

      # --- NIXOS CONFIGURATIONS ----------------------------------------------
      # Defines the actual NixOS systems you want to build.
      nixosConfigurations.nixos-dev = mkNixosConfiguration {
        hostname = "nixos-dev";
        username = "${my_config.home_name}";
        args = {
          minimalBuild = false; # Use full package set for dev
        };
        modules = [
          nixos-wsl.nixosModules.wsl
          ./wsl.nix
        ];
      };

      # CI configuration with minimal packages for faster builds
      nixosConfigurations.nixos-ci = mkNixosConfiguration {
        hostname = "nixos-ci";
        username = "${my_config.home_name}";
        args = {
          minimalBuild = true; # Pass flag for minimal package set
        };
        modules = [
          nixos-wsl.nixosModules.wsl
          ./wsl.nix
        ];
      };
    };
}
