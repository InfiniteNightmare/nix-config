{ inputs, pkgs, ... }:

{
  stylix = {
    # Managed in Home Manager only. Do not configure Stylix in NixOS modules to avoid mismatch.
    enable = true;
    enableReleaseChecks = false;
    base16Scheme = "${inputs.stylix.inputs.tinted-schemes}/base16/tokyo-night-dark.yaml";
    polarity = "dark";

    opacity = {
      terminal = 0.95;
      applications = 1.0;
      desktop = 0.9;
      popups = 0.92;
    };

    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.fira-code;
        name = "FiraCode Nerd Font Mono";
      };
      sansSerif = {
        package = pkgs.noto-fonts;
        name = "Noto Sans";
      };
      serif = {
        package = pkgs.noto-fonts;
        name = "Noto Serif";
      };
      emoji = {
        package = pkgs.noto-fonts-color-emoji;
        name = "Noto Color Emoji";
      };
    };

    targets = {
      foot.colors.enable = false;
      foot.opacity.enable = false;
      zen-browser.profileNames = [ "default" ];
    };
  };
}
