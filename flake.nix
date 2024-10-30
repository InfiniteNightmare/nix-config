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

    anyrun = {
      url = "github:Kirottu/anyrun";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # hyprland.url = "git+https://github.com/hyprwm/Hyprland?submodules=1";
    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      # inputs.hyprland.follows = "hyprland";
    };

    my-nur = {
      url = "github:InfiniteNightmare/nur-packages";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix = {
      url = "github:yaxitech/ragenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprpanel.url = "github:Jas-SinghFSU/HyprPanel";

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      nix-ld,
      anyrun,
      agenix,
      nixos-hardware,
      ...
    }@inputs:
    {
      nixosConfigurations = {
        OptiPlex7000 =
          let
            system = "x86_64-linux";
          in
          nixpkgs.lib.nixosSystem {
            inherit system;
            specialArgs = {
              inherit inputs;
            };
            modules = [
              ./hosts/OptiPlex7000

              nixos-hardware.nixosModules.common-cpu-intel
              nixos-hardware.nixosModules.common-gpu-amd
              nixos-hardware.nixosModules.common-gpu-intel
              nixos-hardware.nixosModules.common-pc
              nixos-hardware.nixosModules.common-pc-ssd

              home-manager.nixosModules.home-manager
              {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.extraSpecialArgs = {
                  inherit inputs;
                };

                home-manager.users.shb = {
                  imports = [
                    ./modules
                    anyrun.homeManagerModules.anyrun
                    agenix.homeManagerModules.default
                  ];
                };
              }

              (args: { nixpkgs.overlays = import ./overlays args; })

              ({
                nixpkgs.overlays = [
                  inputs.hyprpanel.overlay
                ];
              })
            ];
          };
      };
    };
}
