{ pkgs, ... }:
{
  imports = [
    ./mpv.nix
    ./bili-live-tool.nix
  ];

  home.packages = with pkgs; [
    pwvucontrol
    crosspipe
    mpvpaper
    splayer
    obs-studio
  ];
}
