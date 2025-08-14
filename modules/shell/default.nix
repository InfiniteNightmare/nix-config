{ config, pkgs, ... }:
{

  home.file = {
    ".config/nushell" = {
      source = ./nushell;
      recursive = true;
    };

    # ".config/starship.toml".source = ./starship.toml;

    # ".config/zellij/config.kdl".source = ./zellij.kdl;

    ".config/zoxide.nu".source = ./zoxide.nu;

    # ".config/.wezterm.lua".source = ./wezterm.lua;
  };

  programs = {
    nushell = {
      enable = true;
      shellAliases = {
        vi = "hx";
        vim = "hx";
        nano = "hx";
      };
    };

    carapace = {
      enable = true;
      enableNushellIntegration = true;
    };

    starship.enable = true;

    alacritty = {
      enable = true;
      # 自定义配置
      settings = {
        env.TERM = "xterm-256color";
        font = {
          size = 12;
        };
        scrolling.multiplier = 5;
        selection.save_to_clipboard = true;
      };
    };

    # wezterm.enable = true;

    zellij.enable = true;

    zoxide.enable = true;

    yazi = {
      enable = true;
      enableNushellIntegration = true;
    };
  };
}
