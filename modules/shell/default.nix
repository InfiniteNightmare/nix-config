{
  config,
  lib,
  pkgs,
  ...
}:
let
  colors = config.lib.stylix.colors;
in
{
  imports = [
    ./fish
  ];

  programs = {
    starship.enable = true;

    foot = {
      enable = true;
      settings = {
        main = {
          font = lib.mkForce "FiraCodeNerdFontMono:size=12";
        };

        colors-dark = {
          alpha = 0.95;
          foreground = colors.base05;
          background = colors.base00;
          regular0 = colors.base00;
          regular1 = colors.base08;
          regular2 = colors.base0B;
          regular3 = colors.base0A;
          regular4 = colors.base0D;
          regular5 = colors.base0E;
          regular6 = colors.base0C;
          regular7 = colors.base05;
          bright0 = colors.base03;
          bright1 = colors.base08;
          bright2 = colors.base0B;
          bright3 = colors.base0A;
          bright4 = colors.base0D;
          bright5 = colors.base0E;
          bright6 = colors.base0C;
          bright7 = colors.base07;
          "16" = colors.base09;
          "17" = colors.base0F;
          "18" = colors.base01;
          "19" = colors.base02;
          "20" = colors.base04;
          "21" = colors.base06;
        };
      };
    };

    zellij.enable = true;

    tmux = {
      enable = true;
      mouse = true;
      baseIndex = 1;
    };

    zoxide.enable = true;

    yazi = {
      enable = true;
      shellWrapperName = "y";
      extraPackages = [ pkgs.glow ];
      plugins = {
        piper = pkgs.yaziPlugins.piper;
      };
      settings = {
        plugin.prepend_previewers = [
          {
            url = "*.md";
            run = "piper -- CLICOLOR_FORCE=1 glow -w=$w -s=dark \"$1\"";
          }
          {
            url = "*.markdown";
            run = "piper -- CLICOLOR_FORCE=1 glow -w=$w -s=dark \"$1\"";
          }
        ];
      };
    };
  };
}
