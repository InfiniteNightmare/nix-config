{
  lib,
  pkgs,
  config,
  ...
}:

let
  # Wine apps live outside the repo, one dir per app under these roots.
  # `wine-apps` (in PATH) generates a PATH command for every .exe found:
  #   - dirs with a hand-written `launch` get that as <dirname> instead
  #     (never overwritten) and their subtrees are pruned
  #   - generated launches are baselines (GBK locale + per-app prefix),
  #     live next to the exe, and are only regenerated if deleted
  # No HM activation hook: manual-first by design, switching is not involved.
  appRoots = [ "/data/Games" ];

  wineAppsBin = "${config.home.homeDirectory}/.local/share/wine-apps/bin";
in
let
  wine-apps = pkgs.writeShellScriptBin "wine-apps" ''
        # 用法: wine-apps [-f] [目录|exe ...]
        #   无参数      递归扫描全部根目录并生成启动命令
        #   目录        只扫该目录（默认递归，-f 只看第一层）
        #   exe 路径    只为该 exe 生成
        #   -f          非递归（只看目录第一层）
        #   -l          列出现有命令及其指向
        #   -h          显示本帮助
        # 生成的 launch 落在 exe 旁边，可自由编辑；删除后重跑即重新生成。
        # 手写 launch 的目录优先：整棵子树剪枝，目录名即命令。
        bin=${wineAppsBin}
        roots="${lib.concatStringsSep " " appRoots}"
        usage() {
        echo '用法: wine-apps [-f] [-l] [目录|exe ...]'
        echo '  无参数    递归扫描全部根目录并生成启动命令（根: '"$roots"'）'
        echo '  目录      只扫该目录（默认递归，-f 只看第一层）'
        echo '  exe 路径  只为该 exe 生成'
        echo '  -f        非递归'
        echo '  -l        列出现有命令及其指向'
        echo '  -h        显示本帮助'
        echo '生成的 launch 落在 exe 旁边，可自由编辑；删除后重跑即重新生成。'
        }
        flat=0
        list=0
        targets=()
        while getopts "flh" opt; do
          case $opt in
            f) flat=1 ;;
            l) list=1 ;;
            h) usage; exit 0 ;;
            *) usage >&2; exit 1 ;;
          esac
        done
        shift $((OPTIND - 1))
        targets=()
        for a in "$@"; do
          targets+=("$a")
        done

        gen_one() {
          exe=$1
          d=$(dirname "$exe")
          # 手写 launch 的目录整棵剪枝（沿祖先找 launch）
          ad=$d
          while [ "$ad" != "/" ] && [ -n "$ad" ]; do
            [ -e "$ad/launch" ] && return 0
            ad=$(dirname "$ad")
          done
          name=$(basename "$exe" .exe | tr 'A-Z' 'a-z' | sed 's/[^a-z0-9]\+/-/g; s/^-*//; s/-*$//')
          [ -z "$name" ] && return 0
          [ -e "$bin/$name" ] && return 0
          lf="$d/launch-$name"
          if [ ! -e "$lf" ]; then
            {
              echo '#! /usr/bin/env bash'
              echo '# auto-generated baseline launch — edit freely; only regenerated if deleted.'
              echo 'set -e'
              echo 'command -v wine >/dev/null || export PATH="$HOME/.nix-profile/bin:$PATH"'
              echo 'script_dir=$(dirname "$(readlink -f "''${BASH_SOURCE[0]}")")'
              echo 'export WINEPREFIX="$script_dir/wine-pfx"'
              echo 'export LANG=zh_CN.UTF-8 LC_ALL=zh_CN.UTF-8'
              echo "cd '$d'"
              echo '[ -e "$WINEPREFIX/system.reg" ] || wine wineboot -i'
              echo 'exec wine '"$(basename "$exe")"
            } > "$lf"
            chmod +x "$lf"
          fi
          ln -sfn "$lf" "$bin/$name"
        }

        hand_dirs() {
          for d in "$@"/*/; do
            if [ -x "$d"launch ]; then
              ln -sfn "$d"launch "$bin/$(basename "$d")"
            fi
          done
        }

    if [ "$list" = 1 ]; then
      for c in "$bin"/*; do
        [ -e "$c" ] || continue
        printf '%-24s -> %s\n' "$(basename "$c")" "$(readlink "$c")"
      done
      exit 0
    fi
        if [ ''${#targets[@]} -eq 0 ]; then
          rm -rf "$bin"
          mkdir -p "$bin"
          hand_dirs $roots
          find $roots -iname '*.exe' \
            ! -iname '*unins*' ! -iname '*uninst*' ! -iname '*setup*' \
            ! -iname '*redist*' ! -iname '*crash*' ! -iname '*handler*' \
            ! -path '*/wine-pfx/*' -print 2>/dev/null |
          while IFS= read -r exe; do gen_one "$exe"; done
          echo "已生成全部命令: $(ls "$bin" | tr '\n' ' ')"
        else
          mkdir -p "$bin"
          for t in "''${targets[@]}"; do
            if [ -d "$t" ]; then
              [ -x "$t/launch" ] && { ln -sfn "$t/launch" "$bin/$(basename "$t")"; continue; }
              if [ "$flat" = 1 ]; then
                for e in "$t"/*.exe; do [ -e "$e" ] && gen_one "$e"; done
              else
                find "$t" -iname '*.exe' \
                  ! -iname '*unins*' ! -iname '*uninst*' ! -iname '*setup*' \
                  ! -iname '*redist*' ! -iname '*crash*' ! -iname '*handler*' \
                  ! -path '*/wine-pfx/*' -print 2>/dev/null |
                while IFS= read -r e; do gen_one "$e"; done
              fi
            elif [ -f "$t" ]; then
              gen_one "$t"
            else
              echo "wine-apps: 跳过不存在的 $t" >&2
            fi
          done
        fi
  '';
in
{
  home.packages = [
    pkgs.wineWow64Packages.full
    # scales legacy fixed-resolution games to the desktop; see /data launch scripts
    pkgs.gamescope
    # MIDI BGM of legacy games needs a softsynth; launch scripts start it
    # (each app keeps its own .sf2 copy next to the launch script — nix store
    # paths for soundfonts proved too unstable to resolve at runtime)
    pkgs.fluidsynth
    wine-apps
  ];

  home.sessionPath = [ wineAppsBin ];

}
