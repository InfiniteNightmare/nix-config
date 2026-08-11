{ pkgs, ... }:
{
  home.packages = with pkgs; [
    pwvucontrol
    crosspipe
    mpvpaper
    splayer
    obs-studio
  ];
}
