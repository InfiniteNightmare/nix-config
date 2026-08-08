{ lib, pkgs, ... }:

let
  dingtalk = pkgs.nur.repos.xddxdd.dingtalk;
  legacyOpenSSL = pkgs.openssl_1_1;
in
{
  assertions = [
    {
      assertion = lib.any (input: input.name == legacyOpenSSL.name) dingtalk.buildInputs;
      message = ''
        DingTalk no longer lists ${legacyOpenSSL.name} as a build input. Remove it
        from nixpkgs.config.permittedInsecurePackages in modules/home-manager.nix.
      '';
    }
  ];

  home.packages = [ dingtalk ];
}
