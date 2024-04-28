{
  description = "My NixOS flake configuration";

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
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      nix-ld,
      anyrun,
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

              home-manager.nixosModules.home-manager
              {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;

                home-manager.users.shb = {
                  imports = [
                    ./home
                    anyrun.homeManagerModules.anyrun
                    {
                      programs.anyrun = {
                        enable = true;
                        config = {
                          plugins = with anyrun.packages.${system}; [
                            applications
                            rink
                            translate
                          ];
                          x = {
                            fraction = 0.5;
                          };
                          y = {
                            fraction = 0.3;
                          };
                          width = {
                            fraction = 0.3;
                          };
                          hideIcons = false;
                          ignoreExclusiveZones = false;
                          layer = "overlay";
                          hidePluginInfo = false;
                          closeOnClick = false;
                          showResultsImmediately = false;
                          maxEntries = null;
                        };
                        extraCss = ''
                          #window {
                            background-color: rgba(0, 0, 0, 0);
                          }

                          box#main {
                            border-radius: 10px;
                            background-color: @theme_bg_color;
                          }

                          list#main {
                            background-color: rgba(0, 0, 0, 0);
                            border-radius: 10px;
                          }

                          list#plugin {
                            background-color: rgba(0, 0, 0, 0);
                          }

                          label#match-desc {
                            font-size: 10px;
                          }

                          label#plugin {
                            font-size: 14px;
                          }
                        '';
                      };
                    }
                  ];
                };
              }

              nix-ld.nixosModules.nix-ld
              { programs.nix-ld.dev.enable = true; }
            ];
          };
      };
    };
}
