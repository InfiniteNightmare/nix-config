{
  description = "My NixOS flake configuration";

  # outputs = inputs: import ./outputs inputs;

  # the nixConfig here only affects the flake itself, not the system configuration!
  # nixConfig = {
  # substituers will be appended to the default substituters when fetching packages
  # nix com    extra-substituters = [munity's cache server
  # extra-substituters = [ "https://nix-community.cachix.org" ];
  # extra-trusted-public-keys = [
  # "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
  # ];
  # };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-ld = {
      url = "github:Mic92/nix-ld";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    my-nur = {
      url = "github:InfiniteNightmare/nur-packages";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dankMaterialShell = {
      url = "github:AvengeMedia/DankMaterialShell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # more-waita = {
    # url = "github:somepaulo/MoreWaita";
    # flake = false;
    # };

    agenix = {
      url = "github:yaxitech/ragenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    catppuccin.url = "github:catppuccin/nix";

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      # IMPORTANT: we're using "libgbm" and is only available in unstable so ensure
      # to have it up-to-date or simply don't specify the nixpkgs input
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      nix-ld,
      agenix,
      catppuccin,
      nixos-hardware,
      ...
    }@inputs:
    {
      nixosConfigurations = {
        thinkbook =
          let
            system = "x86_64-linux";
          in
          nixpkgs.lib.nixosSystem {
            inherit system;
            specialArgs = {
              inherit inputs;
            };
            modules = [
              ./hosts/thinkbook

              nixos-hardware.nixosModules.common-cpu-amd
              nixos-hardware.nixosModules.common-gpu-amd
              nixos-hardware.nixosModules.common-pc-laptop
              nixos-hardware.nixosModules.common-pc-laptop-ssd

              home-manager.nixosModules.home-manager
              {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.extraSpecialArgs = {
                  inherit inputs;
                };

                home-manager.users.charname = {
                  imports = [
                    ./modules
                    agenix.homeManagerModules.default
                    catppuccin.homeModules.catppuccin
                    inputs.zen-browser.homeModules.default
                    inputs.niri.homeModules.niri
                    inputs.dankMaterialShell.homeModules.dankMaterialShell.default
                    inputs.dankMaterialShell.homeModules.dankMaterialShell.niri
                  ];
                };
              }

              (args: { nixpkgs.overlays = import ./overlays args; })
            ];
          };
      };
    };
}
