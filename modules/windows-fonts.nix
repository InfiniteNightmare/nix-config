{
  lib,
  config,
  ...
}:
# Windows fonts mount module (read-only + direct fontconfig scan)
#
# Goals:
# - Read-only (optional) hidden Windows partition mount for font extraction
# - NO bind mount: fontconfig points directly to ${mountPoint}/Windows/Fonts
# - Optional automount & idle timeout
# - Optional fallback to ntfs-3g if ntfs3 fails
#
# After enabling add (e.g. in host or locale.nix):
# fonts.fontconfig.localConf = ''
#   <fontconfig>
#     <dir>/var/lib/windows-ro/Windows/Fonts</dir>
#   </fontconfig>
# '';
#
let
  inherit (lib)
    mkOption
    mkEnableOption
    types
    mkIf
    mkMerge
    ;

  cfg = config.windowsFonts;

  devicePath = "/dev/disk/by-uuid/${cfg.uuid}";

  # Determine effective ownership: only applied when not readonly (writing scenario)
  effectiveUid = cfg.uid;
  effectiveGid = cfg.gid;

  # Build base options (rw/ro decided by readonly)
  baseMountOptions = [
    (if cfg.readonly then "ro" else "rw")
  ]
  ++ lib.optional (!cfg.readonly && builtins.isInt effectiveUid) "uid=${toString effectiveUid}"
  ++ lib.optional (!cfg.readonly && builtins.isInt effectiveGid) "gid=${toString effectiveGid}"
  ++ (if cfg.readonly then [ "umask=022" ] else cfg.extraMountOptions);

  # Fonts directory (used by fontconfig directly)

  # (bindOptions removed with bind mount removal)
  # (was: bind options list placeholder)
  # (end removed bind options)
  # (bindReadOnly no longer applies without bind mount)
  # (require-mounts-for no longer needed)
in
{
  options.windowsFonts = {
    enable = mkEnableOption "Mount Windows partition and bind its Fonts directory";
    uuid = mkOption {
      type = types.str;
      description = "UUID of the Windows NTFS partition (lsblk -f / blkid).";
    };
    mountPoint = mkOption {
      type = types.str;
      default = "/var/lib/windows-ro";
      description = "Hidden mount point (tight permissions applied).";
    };
    fsType = mkOption {
      type = types.enum [
        "ntfs3"
        "ntfs"
      ];
      default = "ntfs3";
      description = "Preferred fs driver (ntfs3 kernel, ntfs = ntfs-3g fallback).";
    };
    readonly = mkOption {
      type = types.bool;
      default = true;
      description = "Mount partition read-only (recommended while dirty).";
    };
    uid = mkOption {
      type = types.int;
      default = 1000;
      description = "UID to assign (only used when readonly = false).";
    };
    gid = mkOption {
      type = types.int;
      default = 100;
      description = "GID to assign (only used when readonly = false).";
    };
    extraMountOptions = mkOption {
      type = types.listOf types.str;
      default = [ "umask=022" ];
      description = "Extra mount options (ignored for readonly except umask=022 enforced).";
    };
    bindReadOnly = mkOption {
      type = types.bool;
      default = true;
      description = "Bind Windows Fonts directory as read-only.";
    };
    allowFail = mkOption {
      type = types.bool;
      default = true;
      description = "Add nofail to avoid emergency mode if partition unavailable.";
    };
    autoMount = mkOption {
      type = types.bool;
      default = true;
      description = "Use x-systemd.automount for on-demand mounting.";
    };
    autoMountIdleTimeout = mkOption {
      type = types.str;
      default = "30s";
      description = "Idle timeout for automount (ignored if autoMount = false).";
    };
    autoFallback = mkOption {
      type = types.bool;
      default = false;
      description = "If true and fsType=ntfs3 mount fails, attempt ntfs (ntfs-3g) fallback (read-only preserved).";
    };
    refreshFontCacheOnActivation = mkOption {
      type = types.bool;
      default = true;
      description = "Run fc-cache -f on activation if fonts visible.";
    };
    # Bind mount removed – direct scan of ${cfg.mountPoint}/Windows/Fonts instead.
  };

  config = mkIf cfg.enable (mkMerge [
    {
      boot.supportedFilesystems = lib.mkBefore [ "ntfs" ];

      # Hidden mount directory permissions
      systemd.tmpfiles.rules = [
        "d ${cfg.mountPoint} 0700 root root -"
        "d /usr/local/share/fonts 0755 root root -"
      ];

      fileSystems."${cfg.mountPoint}" = {
        device = devicePath;
        fsType = cfg.fsType;
        options =
          baseMountOptions
          ++ lib.optional cfg.allowFail "nofail"
          ++ lib.optionals cfg.autoMount [
            "x-systemd.automount"
            "x-systemd.idle-timeout=${cfg.autoMountIdleTimeout}"
          ];
      };
    }

    # Bind mount logic removed – cache refresh should target the real directory via fontconfig scan.

    # Fallback service (ntfs3 -> ntfs-3g) only if enabled
    (mkIf (cfg.autoFallback && cfg.fsType == "ntfs3") {
      systemd.services.windowsFonts-fallback = {
        description = "Fallback to ntfs-3g if ntfs3 mount failed";
        after = [ "local-fs.target" ];
        wants = [ "local-fs.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig.Type = "oneshot";
        script = ''
          set -eu
          MP='${cfg.mountPoint}'
          DEV='${devicePath}'
          # Already mounted? exit
          if mountpoint -q "$MP"; then
            exit 0
          fi
          echo "[windowsFonts] ntfs3 mount not active; attempting fallback..."
          # Try ntfs3 RO or RW depending on readonly flag
          MODE_OPTS="${if cfg.readonly then "ro" else "rw"}"
          if mount -t ntfs3 -o $MODE_OPTS,umask=022 "$DEV" "$MP" 2>/dev/null; then
            echo "[windowsFonts] ntfs3 fallback succeeded (late)."
            exit 0
          fi
          echo "[windowsFonts] ntfs3 retry failed; trying ntfs-3g..."
          if command -v mount.ntfs >/dev/null 2>&1; then
            if mount -t ntfs -o $MODE_OPTS,umask=022 "$DEV" "$MP"; then
              echo "[windowsFonts] switched to ntfs-3g."
              exit 0
            fi
          else
            echo "[windowsFonts] ntfs-3g helper missing (install ntfs3g for fallback)."
          fi
          echo "[windowsFonts] fallback failed."
          exit 0
        '';
      };
    })

    {
      assertions = [
        {
          assertion = cfg.uuid != "";
          message = "windowsFonts.uuid must be non-empty";
        }
        # Removed bind mount assertion (no bind mode).
        {
          assertion = (!cfg.autoMount) || (cfg.autoMountIdleTimeout != "");
          message = "windowsFonts.autoMountIdleTimeout must be non-empty when autoMount = true";
        }
      ];
    }
  ]);
}
