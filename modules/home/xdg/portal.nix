{ config, pkgs, ... }:
{
  home = {
    packages = [ pkgs.xdg-utils ];
    sessionVariables.GTK_USE_PORTAL = "1";
  };

  xdg = {
    enable = true;

    configFile."xdg-desktop-portal-termfilechooser/config".text = ''
      [filechooser]
      cmd=${pkgs.bash}/bin/bash ${config.home.homeDirectory}/.config/xdg-desktop-portal-termfilechooser/yazi-wrapper.sh
      default_dir=${config.home.homeDirectory}
    '';

    configFile."xdg-desktop-portal-termfilechooser/yazi-wrapper.sh" = {
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
            # Enter saves as the suggested name in the hovered file's directory; q/close cancels.
            # yazi streams its live cwd over DDS (--local-events=cd, TUI stays on /dev/tty); a
            # fifo consumer replants the suggested-name placeholder into every visited dir.
            name=$(basename -- "$path")
            mkdir -p -- "$(dirname -- "$path")" 2>/dev/null || true
            touch -- "$path" 2>/dev/null || true
            events=/tmp/termfilechooser-events.$$
            mkfifo -- "$events"
            trap 'rm -f -- "$events"' EXIT
            (
                last=""
                while IFS= read -r line; do
                    [ "''${line%%,*}" = "cd" ] || continue
                    dir=$(printf '%s' "$line" | sed -n 's/.*"url":"\([^"]*\)".*/\1/p')
                    [ -n "$dir" ] || continue
                    target=$dir/$name
                    if [ "$target" != "$last" ]; then
                        if [ ! -e "$target" ]; then
                            touch -- "$target" 2>/dev/null || continue
                        elif [ -s "$target" ]; then
                            continue
                        fi
                        if [ -n "$last" ] && [ ! -s "$last" ]; then
                            rm -f -- "$last"
                        fi
                        last=$target
                    fi
                done < "$events"
            ) &
            watcher=$!
            # hold the write end so the consumer can never block on open if yazi fails to start
            exec 3>"$events"
            set -- --chooser-file="$out" --cwd-file="$out"".cwd" --local-events=cd "$path"
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

        if [ "$save" = "1" ]; then
            # yazi's stdout must be the events fifo; the server-side shell does the
            # redirect because footclient spawns commands with the window pty
            ${pkgs.foot}/bin/footclient --title termfilechooser ${pkgs.bash}/bin/bash -c '
                ev=$1
                shift
                exec '"${config.programs.yazi.finalPackage}"'/bin/yazi "$@" > "$ev"
            ' tfd "$events" "$@"
        else
            ${pkgs.foot}/bin/footclient --title termfilechooser ${config.programs.yazi.finalPackage}/bin/yazi "$@"
        fi

        if [ "$save" = "1" ]; then
            kill "$watcher" 2>/dev/null || true
            chosen=$(head -n1 -- "$out" 2>/dev/null || true)
            if [ -n "$chosen" ]; then
                printf '%s/%s\n' "$(dirname -- "$chosen")" "$name" > "$out"
                landing=$(dirname -- "$chosen")/$name
            else
                : > "$out"
                landing=""
            fi
            # sweep the watcher's last plant and the initial placeholder; keep the landing file
            if [ -s "$out"".cwd" ]; then
                final=$(cat -- "$out"".cwd")/$name
                if [ "$final" != "$landing" ] && [ ! -s "$final" ]; then
                    rm -f -- "$final"
                fi
            fi
            if [ "$path" != "$landing" ] && [ ! -s "$path" ]; then
                rm -f -- "$path"
            fi
            rm -f -- "$out"".cwd"
        elif [ "$directory" = "1" ]; then
            if [ ! -s "$out" ] && [ -s "$out"".1" ]; then
                cat -- "$out"".1" > "$out"
            fi
            rm -f -- "$out"".1"
        fi
      '';
    };
  };
}
