{ config, pkgs, ... }:

let
  wallpaperDirectory = "${config.home.homeDirectory}/Pictures/Wallpaper/wallhaven/touhou-project";
in
{
  home.packages = with pkgs; [
    wl-clipboard
    gnome-keyring
    grim
    slurp
    xcur2png
  ];

  # Keep the printer available without starting a tray applet on every login.
  xdg.configFile."autostart/print-applet.desktop".text = ''
    [Desktop Entry]
    Hidden=true
  '';

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
