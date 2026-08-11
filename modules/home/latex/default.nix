{ pkgs, ... }:

{
  home.packages = with pkgs; [
    texliveFull
    poppler-utils
  ];
}
