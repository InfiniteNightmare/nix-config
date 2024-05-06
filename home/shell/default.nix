{ config, pkgs, ... }:
{

  home.file = {
    ".config/nushell" = {
      source = ./nushell;
      recursive = true;
    };

    ".config/starship.toml".source = ./starship.toml;

    ".config/zellij/config.kdl".source = ./zellij.kdl;
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

    helix = {
      enable = true;
      settings = {
        theme = "autumn_night_transparent";
        editor.cursor-shape = {
          normal = "block";
          insert = "bar";
          select = "underline";
        };
      };
      languages.language = [
        {
          name = "nix";
          auto-format = true;
          formatter.command = "${pkgs.nixfmt-rfc-style}/bin/nixfmt";
        }
      ];
      themes = {
        autumn_night_transparent = {
          "inherits" = "autumn_night";
          "ui.background" = { };
        };
      };
    };

    zellij.enable = true;
  };
}
