{
  inputs,
  userName,
  ...
}:

{
  imports = [ inputs.home-manager.nixosModules.home-manager ];

  home-manager = {
    # Noctalia still defines Home Manager-specific overlays, so it cannot safely
    # share the system package set yet.
    useGlobalPkgs = false;
    useUserPackages = true;
    extraSpecialArgs = {
      inherit inputs userName;
    };

    users.${userName} = {
      imports = [
        ./default.nix
        inputs.agenix.homeManagerModules.default
        inputs.stylix.homeModules.stylix
        inputs.zen-browser.homeModules.default
        inputs.noctalia.homeModules.default
      ];

      nixpkgs.config.allowUnfree = true;
    };
  };
}
