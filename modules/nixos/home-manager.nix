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
        inputs.nixvim.homeModules.nixvim
        inputs.stylix.homeModules.stylix
        inputs.zen-browser.homeModules.default
      ];

      nixpkgs.config.allowUnfree = true;
      # zotero 10.0.6 pairs the vendored esr-140-bin — EOL runtime, same one the
      # retired lib/zotero-upstream.nix tarball shipped
      nixpkgs.config.permittedInsecurePackages = [
        "firefox-esr-140-bin-unwrapped-140.17.0esr"
      ];
      # fcitx5's gtk2 immodule cache keeps EOL gtk2 alive for gtk2 apps (WPS)
      nixpkgs.config.problems.handlers."gtk+".broken = "warn";
    };
  };
}
