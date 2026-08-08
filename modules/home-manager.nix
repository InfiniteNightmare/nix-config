{
  config,
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
      minimaxEnvFile = config.age.secrets.minimax-env.path;
    };

    users.${userName} = {
      imports = [
        ./default.nix
        ./dingtalk
        inputs.agenix.homeManagerModules.default
        inputs.stylix.homeModules.stylix
        inputs.zen-browser.homeModules.default
        inputs.noctalia.homeModules.default
      ];

      nixpkgs = {
        config = {
          allowUnfree = true;
          # Required by NUR's DingTalk package. The dingtalk module asserts that
          # this exception becomes stale when the package stops using OpenSSL 1.1.
          permittedInsecurePackages = [ "openssl-1.1.1w" ];
        };
        overlays = [ inputs.nur.overlays.default ];
      };
    };
  };
}
