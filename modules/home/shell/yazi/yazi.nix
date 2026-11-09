{
  lib,
  pkgs,
  inputs,
  ...
}:

let
  # Single-file local plugins: <name>.lua is auto-wrapped into the
  # <name>.yazi/main.lua layout yazi requires. git add new files or the
  # flake's git-tree filter hides them silently.
  plugins = builtins.readDir ./plugins;
  luaFiles = lib.filterAttrs (file: type: type == "regular" && lib.hasSuffix ".lua" file) plugins;

  localPlugins = lib.mapAttrs' (
    file: _:
    lib.nameValuePair (lib.removeSuffix ".lua" file) (
      pkgs.writeTextDir "main.lua" (builtins.readFile (./plugins/${file}))
    )
  ) luaFiles;

  # User plugins are not auto-setup like presets, but ones registering
  # remotes (opener targets) need it. The guard skips plain plugins.
  initLua = ''
    for _, name in ipairs(${
      lib.generators.toLua { } (lib.mapAttrsToList (file: _: lib.removeSuffix ".lua" file) luaFiles)
    }) do
      local ok, plugin = pcall(require, name)
      if ok and type(plugin.setup) == "function" then
        plugin:setup()
      end
    end
  ''
  + builtins.readFile ./init.lua;

  # 26.9 silently drops `open` on FUSE mounts (open waits on mime fetches
  # that never finish, then open_do filters out empty mimes); 26.8.15 predates
  # all of that. Remove this input to go back to nixpkgs HEAD once upstream
  # fixes it. Re-verification recipe (also in memory): `nix flake update`, drop
  # this input, then Enter on an /mnt/fnos mkv in tmux yazi — mpv must launch.
  # The extension open rules above keep working on both versions.
  yaziPkg =
    let
      p = inputs.nixpkgs-yazi.legacyPackages.${pkgs.stdenv.hostPlatform.system}.yazi;
    in
    if p.version == "26.8.15" then
      p
    else
      throw "yazi pin drifted to ${p.version}; re-verify the FUSE open bug (comment above) before re-pinning";
in
{
  programs.yazi = {
    enable = true;
    package = yaziPkg;
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
    }
    // localPlugins;
    inherit initLua;
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
        on = [
          "m"
          "t"
        ];
        run = "linemode size_and_mtime";
        desc = "Linemode: size and mtime";
      }
      {
        on = [ "E" ];
        run = "plugin decompress";
        desc = "Smart extract (password prompt)";
      }
    ];
    settings = {
      mgr.linemode = "size_and_mtime";
      mgr.sort_by = "natural";
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
      # Builtin extract cannot decode WinRAR 7+ (RAR5 v6) and refuses zips
      # with junk prepended (disguised files); preset plugins cannot be
      # overridden by user plugins (loader cache), hence the separate name.
      opener."decompress" = [
        {
          run = "ya pub decompress --list %s";
          desc = "Extract here (decompress)";
        }
      ];
      open.prepend_rules = [
        # Videos open via the `play` opener directly: on the pinned 26.8 it is
        # `mpv`, and this skips xdg-open's second mime probe of the remote file.
        {
          url = "*.mkv";
          use = [ "play" ];
        }
        {
          url = "*.mp4";
          use = [ "play" ];
        }
        {
          url = "*.avi";
          use = [ "play" ];
        }
        {
          url = "*.mov";
          use = [ "play" ];
        }
        {
          url = "*.webm";
          use = [ "play" ];
        }
        {
          url = "*.wmv";
          use = [ "play" ];
        }
        {
          url = "*.ts";
          use = [ "play" ];
        }
        {
          url = "*.m2ts";
          use = [ "play" ];
        }
      ]
      ++ [
        {
          url = "*.rar";
          use = [ "decompress" ];
        }
        {
          url = "*.zip";
          use = [ "decompress" ];
        }
        {
          url = "*.7z";
          use = [ "decompress" ];
        }
      ];
    };
  };
}
