{
  lib,
  config,
  ...
}:
# Windows fonts mount module (read-only + direct fontconfig scan)
#
# Goals:
# - Optionally mount a Windows partition read-only for font access
# - Let fontconfig scan ${mountPoint}/Windows/Fonts directly
# - Support on-demand mounting through systemd automount
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

in
{
  options.windowsFonts = {
    enable = mkEnableOption "mounting a Windows partition for direct fontconfig access";
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
        "ntfs"
        "ntfs3"
      ];
      default = "ntfs";
      description = "Filesystem driver: Linux 7.1+ NTFS or the older ntfs3 driver.";
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
  };

  config = mkIf cfg.enable {
    boot.supportedFilesystems = lib.mkBefore [ cfg.fsType ];

    systemd.tmpfiles.rules = [
      "d ${cfg.mountPoint} 0700 root root -"
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

    assertions = [
      {
        assertion = cfg.uuid != "";
        message = "windowsFonts.uuid must be non-empty";
      }
      {
        assertion = (!cfg.autoMount) || (cfg.autoMountIdleTimeout != "");
        message = "windowsFonts.autoMountIdleTimeout must be non-empty when autoMount = true";
      }
    ];
  };
}
