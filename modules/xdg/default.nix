{ config, pkgs, ... }:
{
  imports = [
    ./mime.nix
    ./yazi-file-manager.nix
  ];

  xdg.configFile."xdg-desktop-portal-termfilechooser/config".text = ''
    [filechooser]
    cmd=${pkgs.bash}/bin/bash ${config.home.homeDirectory}/.config/xdg-desktop-portal-termfilechooser/yazi-wrapper.sh
    default_dir=${config.home.homeDirectory}
  '';

  xdg.configFile."xdg-desktop-portal-termfilechooser/yazi-wrapper.sh" = {
    executable = true;
    text = ''
      #!/usr/bin/env sh
      # This wrapper script is invoked by xdg-desktop-portal-termfilechooser.
      #
      # For more information about input/output arguments read `xdg-desktop-portal-termfilechooser(5)`

      set -e

      if [ "$6" -ge 4 ]; then
          set -x
      fi

      multiple="$1"
      directory="$2"
      save="$3"
      path="$4"
      out="$5"

      if [ "$save" = "1" ]; then
          # save a file
          set -- --chooser-file="$out" "$path"
      elif [ "$directory" = "1" ]; then
          # upload files from a directory
          set -- --chooser-file="$out" --cwd-file="$out"".1" "$path"
      elif [ "$multiple" = "1" ]; then
          # upload multiple files
          set -- --chooser-file="$out" "$path"
      else
          # upload only 1 file
          set -- --chooser-file="$out" "$path"
      fi

      ${pkgs.foot}/bin/footclient --title termfilechooser ${config.programs.yazi.finalPackage}/bin/yazi "$@"

      if [ "$directory" = "1" ]; then
          if [ ! -s "$out" ] && [ -s "$out"".1" ]; then
              cat -- "$out"".1" > "$out"
          fi
          rm -f -- "$out"".1"
      fi
    '';
  };
}
