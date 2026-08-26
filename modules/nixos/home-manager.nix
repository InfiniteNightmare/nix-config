{
  inputs,
  moduleFiles,
  userName,
  ...
}:

{
  imports = [ inputs.home-manager.nixosModules.home-manager ];

  home-manager = {
    # Home Manager keeps its own package set so the per-user nixpkgs.config below
    # stays effective.
    useGlobalPkgs = false;
    useUserPackages = true;
    extraSpecialArgs = {
      inherit inputs userName;
    };

    users.${userName} = {
      imports = moduleFiles ../home ++ [
        inputs.agenix.homeManagerModules.default
        inputs.stylix.homeModules.stylix
        inputs.zen-browser.homeModules.default
      ];

      nixpkgs.config.allowUnfree = true;
    };
  };
}
