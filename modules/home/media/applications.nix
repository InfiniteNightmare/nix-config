{ pkgs, ... }:
{
  home.packages = with pkgs; [
    pwvucontrol
    crosspipe
    mpvpaper
    splayer-next
    obs-studio
  ];
}
