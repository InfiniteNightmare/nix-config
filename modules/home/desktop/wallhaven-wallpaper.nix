{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.services.wallhavenWallpaper;
  ratios = lib.concatStringsSep "," cfg.ratios;
  minimumResolution = "${toString cfg.minimumWidth}x${toString cfg.minimumHeight}";

  syncScript = pkgs.writeShellApplication {
    name = "wallhaven-wallpaper-sync";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.findutils
      pkgs.gawk
      pkgs.jq
    ];
    text = ''
      set -euo pipefail

      directory=${lib.escapeShellArg cfg.directory}
      query=${lib.escapeShellArg cfg.query}
      categories=${lib.escapeShellArg cfg.categories}
      purity=${lib.escapeShellArg cfg.purity}
      ratios=${lib.escapeShellArg ratios}
      minimum_resolution=${lib.escapeShellArg minimumResolution}
      sorting=${lib.escapeShellArg cfg.sorting}
      order=${lib.escapeShellArg cfg.order}
      per_page=${toString cfg.perPage}
      daily_limit=${toString cfg.dailyLimit}
      keep=${toString cfg.keep}

      mkdir -p "$directory"

      workdir="$(mktemp -d)"
      trap 'rm -rf "$workdir"' EXIT

      search_json="$workdir/search.json"
      seed="$(date +%Y%m%d)"

      curl -fsSLG "https://wallhaven.cc/api/v1/search" \
        --data-urlencode "q=$query" \
        --data "categories=$categories" \
        --data "purity=$purity" \
        --data-urlencode "ratios=$ratios" \
        --data-urlencode "atleast=$minimum_resolution" \
        --data "sorting=$sorting" \
        --data "order=$order" \
        --data "per_page=$per_page" \
        --data-urlencode "seed=$seed" \
        -o "$search_json"

      jq -r '.data[] | [.id, .path] | @tsv' "$search_json" \
        | shuf \
        > "$workdir/items-all.tsv"
      head -n "$daily_limit" "$workdir/items-all.tsv" > "$workdir/items.tsv"

      while IFS=$'\t' read -r id url; do
        if [ -z "$id" ] || [ -z "$url" ]; then
          continue
        fi

        extension=''${url##*.}
        target="$directory/wallhaven-$id.$extension"

        if [ -s "$target" ]; then
          continue
        fi

        partial="$target.part"
        rm -f "$partial"
        curl -fsSL --retry 3 --retry-delay 2 -o "$partial" "$url"
        mv "$partial" "$target"
      done < "$workdir/items.tsv"

      if [ "$keep" -gt 0 ]; then
        count=0
        while IFS= read -r -d $'\0' entry; do
          count=$((count + 1))
          if [ "$count" -le "$keep" ]; then
            continue
          fi

          rm -f -- "''${entry#* }"
        done < <(
          find "$directory" -maxdepth 1 -type f \
            \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
            -printf '%T@ %p\0' \
            | sort -zrn
        )
      fi
    '';
  };
in
{
  options.services.wallhavenWallpaper = {
    enable = mkEnableOption "automatic Wallhaven wallpaper downloads";

    directory = mkOption {
      type = types.str;
      default = "${config.home.homeDirectory}/Pictures/Wallpaper/wallhaven/touhou-project";
      description = "Directory where downloaded wallpapers are stored.";
    };

    query = mkOption {
      type = types.str;
      default = "touhou project";
      description = "Wallhaven search query.";
    };

    categories = mkOption {
      type = types.str;
      default = "010";
      description = "Wallhaven category bitmask: general/anime/people.";
    };

    purity = mkOption {
      type = types.str;
      default = "100";
      description = "Wallhaven purity bitmask: SFW/sketchy/NSFW.";
    };

    ratios = mkOption {
      type = types.listOf types.str;
      default = [
        "16x10"
        "16x9"
        "21x9"
      ];
      description = "Allowed wallpaper aspect ratios.";
    };

    minimumWidth = mkOption {
      type = types.ints.positive;
      default = 2560;
      description = "Minimum wallpaper width requested from Wallhaven.";
    };

    minimumHeight = mkOption {
      type = types.ints.positive;
      default = 1440;
      description = "Minimum wallpaper height requested from Wallhaven.";
    };

    sorting = mkOption {
      type = types.enum [
        "date_added"
        "relevance"
        "random"
        "views"
        "favorites"
        "toplist"
      ];
      default = "random";
      description = "Wallhaven search sorting.";
    };

    order = mkOption {
      type = types.enum [
        "asc"
        "desc"
      ];
      default = "desc";
      description = "Wallhaven search order.";
    };

    perPage = mkOption {
      type = types.ints.positive;
      default = 24;
      description = "Number of Wallhaven results to inspect per run.";
    };

    dailyLimit = mkOption {
      type = types.ints.positive;
      default = 6;
      description = "Maximum wallpapers to download per run.";
    };

    keep = mkOption {
      type = types.int;
      default = 120;
      description = "Maximum local wallpapers to keep. Set to 0 to disable pruning.";
    };

    onCalendar = mkOption {
      type = types.str;
      default = "*-*-* 11:40:00";
      description = "Systemd calendar expression for scheduled downloads.";
    };

    onBootSec = mkOption {
      type = types.str;
      default = "30s";
      description = "Delay before the first boot-time download attempt.";
    };

    randomizedDelaySec = mkOption {
      type = types.str;
      default = "5m";
      description = "Random delay added by systemd to avoid a fixed request time.";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ syncScript ];

    home.activation.createWallhavenWallpaperDirectory = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p ${lib.escapeShellArg cfg.directory}
    '';

    systemd.user.services.wallhaven-wallpaper = {
      Unit = {
        Description = "Download Touhou Project wallpapers from Wallhaven";
        Documentation = "https://wallhaven.cc/help/api";
        After = [ "network-online.target" ];
      };

      Service = {
        Type = "oneshot";
        ExecStart = "${syncScript}/bin/wallhaven-wallpaper-sync";
        Nice = 10;
        IOSchedulingClass = "idle";
      };
    };

    systemd.user.timers.wallhaven-wallpaper = {
      Unit.Description = "Schedule Wallhaven wallpaper downloads";

      Timer = {
        OnBootSec = cfg.onBootSec;
        OnCalendar = cfg.onCalendar;
        Persistent = true;
        RandomizedDelaySec = cfg.randomizedDelaySec;
      };

      Install.WantedBy = [ "timers.target" ];
    };
  };
}
