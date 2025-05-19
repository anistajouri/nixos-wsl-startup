{
  description = "NixOS configuration";

  # https://github.com/nixos/nixpkgs#nixpkgs : nixos-24.11 (last stable release)
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";

  # Home Manager
  # tool that manages user configuration files (home.nix)
  # GitHub Repository: https://github.com/nix-community/home-manager
  # Specific Branch: https://github.com/nix-community/home-manager/tree/release-24.11
  inputs.home-manager.url = "github:nix-community/home-manager/release-24.11";
  inputs.home-manager.inputs.nixpkgs.follows = "nixpkgs";

  # https://github.com/nix-community/NixOS-WSL : WSL support for NixOS
  inputs.nixos-wsl.url = "github:nix-community/NixOS-WSL";
  inputs.nixos-wsl.inputs.nixpkgs.follows = "nixpkgs";

  
  # nix-index-database: allows to search for packages in the NixOS ecosystem if not found
  inputs.nix-index-database.url = "github:nix-community/nix-index-database";
  inputs.nix-index-database.inputs.nixpkgs.follows = "nixpkgs";

  inputs.lvim.url = "/mnt/d/nix/LVim";

  outputs = inputs:
    with inputs; let
      my_config = builtins.fromJSON (builtins.readFile "${self}/my_config.json");

      nixpkgsWithOverlays = system: (import nixpkgs rec {
        inherit system;

        config = {
          allowUnfree = true;
          permittedInsecurePackages = [
          ];
        };

        overlays = [
          lvim.overlays.default
        ];
      });

      configurationDefaults = args: {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.backupFileExtension = "hm-backup";
        home-manager.extraSpecialArgs = args;
      };

      argDefaults = {
        inherit my_config inputs self nix-index-database;
        channels = {
          inherit nixpkgs;
        };
      };

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
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.alejandra;

      nixosConfigurations.nixos-dev = mkNixosConfiguration {
        hostname = "nixos-dev";
        username = "${my_config.home_name}";
        modules = [
          nixos-wsl.nixosModules.wsl
          ./wsl.nix
        ];
      };
    };
}