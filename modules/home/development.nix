{ pkgs, ... }:
{
  home.packages = with pkgs; [
    gnumake
    nix-output-monitor
    hugo
    slidev-cli
    gh
    uv
    devbox
    nixd
  ];

  programs = {
    git = {
      enable = true;
      settings = {
        user.name = "InfiniteNightmare";
        user.email = "742851870@qq.com";
      };
    };

    direnv = {
      enable = true;
      enableBashIntegration = true;
      nix-direnv.enable = true;
    };
  };
}
