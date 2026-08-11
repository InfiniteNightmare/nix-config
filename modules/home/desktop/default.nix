{ config, ... }:

let
  wallpaperDirectory = "${config.home.homeDirectory}/Pictures/Wallpaper/wallhaven/touhou-project";
in
{
  imports = [
    ./language-tools
    ./niri.nix
    ./noctalia.nix
    ./wallhaven-wallpaper.nix
  ];

  services.wallhavenWallpaper = {
    enable = true;
    directory = wallpaperDirectory;
    query = "touhou project";
    categories = "010";
    purity = "100";
    ratios = [
      "16x10"
      "16x9"
      "21x9"
    ];
    minimumWidth = 2560;
    minimumHeight = 1440;
    sorting = "random";
    dailyLimit = 6;
    keep = 120;
  };
}
