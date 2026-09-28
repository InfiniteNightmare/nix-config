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
        # yazi 26.x Lua API breaks nixpkgs' compress.yazi 0.6:
        # fs.unique_name -> fs.unique(type, url), and tab.selected now yields
        # File objects without a .parent field. Shim both; drop this once
        # nixpkgs packages a compatible upstream release (replace-fail will
        # make the build fail loudly as the signal).
        compress = pkgs.yaziPlugins.compress.overrideAttrs (old: {
          postPatch = (old.postPatch or "") + ''
            substituteInPlace main.lua \
              --replace-fail 'fs.unique_name(Url(temp_dir))' 'fs.unique("dir", Url(temp_dir))' \
              --replace-fail 'local temp_dir_status, temp_dir_err = fs.create("dir_all", Url(temp_dir))' 'local temp_dir_status, temp_dir_err = true, nil' \
              --replace-fail 'fs.unique_name(Url(final_output_url))' 'fs.unique("file", Url(final_output_url))' \
              --replace-fail 'paths[#paths + 1] = tostring(u.parent)' 'paths[#paths + 1] = tostring(u.url.parent)'
          '';
        });
        extract-rar = ./yazi-extract-rar;
      };
      initLua = ./yazi-extract-rar/init.lua;
      keymap.mgr.prepend_keymap = [
        {
          on = [
            "c"
            "a"
            "a"
          ];
          run = "plugin compress";
          desc = "Archive selected files";
        }
        {
          on = [
            "c"
            "a"
            "p"
          ];
          run = "plugin compress -p";
          desc = "Archive selected files (password)";
        }
        {
          on = [ "E" ];
          run = "plugin extract-rar";
          desc = "Extract rar with unrar (password prompt)";
        }
      ];
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
        # yazi's builtin extract cannot decode WinRAR 7+ (RAR5 v6) archives:
        # its 7zz/7z-only pipeline reports "Unsupported Method" and moves out
        # a 0-byte file. Route .rar to the extract-rar plugin (unrar) instead;
        # preset plugins cannot be overridden by user plugins (loader cache),
        # hence the separate name.
        opener."extract-rar" = [
          {
            run = "ya pub extract-rar --list %s";
            desc = "Extract here (unrar)";
          }
        ];
        open.prepend_rules = [
          {
            url = "*.rar";
            use = [ "extract-rar" ];
          }
        ];
      };
    };
  };
}
