{
  lib,
  config,
  pkgs,
  ...
}:
#
# Refactored WebDAV multi-mount module using `rclone`.
#
# This module replaces the old davfs2 implementation.
#
# Important: we use NixOS `fileSystems` with `fsType = "rclone"` (mount.rclone)
# so the FUSE mount is visible system-wide (no systemd private mount namespace).
# Age-encrypted passwords are decrypted on demand after /home is available and
# written only to /run for the lifetime of the mount configuration.
#
let
  inherit (lib)
    mkEnableOption
    mkOption
    mkIf
    types
    optionalString
    hasPrefix
    removePrefix
    ;

  cfg = config.filesystems.webdav;

  identityArgs = lib.concatMapStringsSep " " (
    path: "-i ${lib.escapeShellArg path}"
  ) cfg.identityPaths;

  # Heuristic defaults for ownership
  defaultUserName = "charname";
  defaultUid =
    let
      users = config.users.users;
    in
    # NixOS may not assign a numeric uid until later unless explicitly set.
    # Guard against `null` so we never emit an empty `--uid` argument.
    if builtins.hasAttr defaultUserName users && users.${defaultUserName}.uid != null then
      users.${defaultUserName}.uid
    else
      1000;

  defaultGid = 100;

  mountSubmodule =
    { name, ... }:
    {
      options = {
        url = mkOption {
          type = types.str;
          description = "WebDAV endpoint URL.";
        };
        username = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Username for authentication.";
        };
        encryptedPasswordFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = "Age-encrypted file containing the WebDAV password.";
        };
        password = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Inline plain password (discouraged).";
        };
        mountPoint = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Override mount point (default /mnt/<name>).";
        };
        readOnly = mkOption {
          type = types.bool;
          default = false;
          description = "Mount read-only if true.";
        };
        automount = mkOption {
          type = types.bool;
          default = true;
          description = "Whether to mount automatically on boot.";
        };
        cache = {
          enable = mkOption {
            type = types.bool;
            default = true;
            description = "Enable rclone vfs caching.";
          };
          sizeMiB = mkOption {
            type = types.int;
            default = 5000; # Default to 5GB for rclone
            description = "Max cache size in MiB (when cache.enable = true). Note: This acts as the max size for rclone's sparse cache.";
          };
          baseDir = mkOption {
            type = types.str;
            default = "/var/cache/rclone";
            description = "Base directory for per-mount cache subdirectories.";
          };
        };
        extraOptions = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Extra arguments to pass to rclone mount.";
        };
      };
    };

  # Convert attrset of mounts to a list to generate systemd services
  normalizedMounts = lib.mapAttrsToList (
    name: m:
    let
      mp = if m.mountPoint == null then "/mnt/${name}" else m.mountPoint;
      cacheDir = if m.cache.enable then "${m.cache.baseDir}/${name}" else null;
      runConfigDir = "/run/rclone";
      runConfigPath = "${runConfigDir}/${name}.conf";

      # Accept both `--flag` style and `flag` style options.
      normalizeMountOption = opt: if hasPrefix "--" opt then removePrefix "--" opt else opt;
    in
    {
      inherit
        name
        mp
        cacheDir
        runConfigDir
        runConfigPath
        normalizeMountOption
        ;
      m = m;
    }
  ) cfg.mounts;

in
{
  options.filesystems.webdav = {
    enable = mkEnableOption "Simplified WebDAV multi-mount management (powered by rclone)";
    identityPaths = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Runtime private key paths used to decrypt encrypted WebDAV passwords.";
    };
    mounts = mkOption {
      type = types.attrsOf (types.submodule mountSubmodule);
      default = { };
      description = "Attribute set of named WebDAV mounts.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = normalizedMounts != [ ];
        message = "filesystems.webdav.enable = true but no mounts defined.";
      }
    ]
    ++ map (nm: {
      assertion = nm.m.url != "";
      message = "webdav mount ${nm.mp}: url cannot be empty.";
    }) normalizedMounts
    ++ map (nm: {
      assertion = !(nm.m.password != null && nm.m.encryptedPasswordFile != null);
      message = "webdav mount ${nm.mp}: cannot set both password and encryptedPasswordFile.";
    }) normalizedMounts
    ++ map (nm: {
      assertion =
        (nm.m.password == null && nm.m.encryptedPasswordFile == null) || (nm.m.username != null);
      message = "webdav mount ${nm.mp}: username required when a password is provided.";
    }) normalizedMounts
    ++ [
      {
        assertion = builtins.all (
          nm: nm.m.encryptedPasswordFile == null || cfg.identityPaths != [ ]
        ) normalizedMounts;
        message = "webdav mounts using encryptedPasswordFile require filesystems.webdav.identityPaths.";
      }
    ];

    # Ensure fuse is available for allow_other
    programs.fuse.userAllowOther = true;
    environment.systemPackages = [ pkgs.rclone ];

    # Create mount points and cache directories
    systemd.tmpfiles.rules =
      (map (nm: "d ${nm.mp} 0755 root root -") normalizedMounts)
      ++ (map (nm: "d ${nm.runConfigDir} 0750 root root -") normalizedMounts)
      ++ (map (nm: "d ${nm.cacheDir} 0700 root root -") (
        lib.filter (nm: nm.cacheDir != null) normalizedMounts
      ));

    # Generate ephemeral rclone config in /run for each mount.
    # This keeps credentials out of the nix store and out of the repo.
    systemd.services = lib.foldl' lib.recursiveUpdate { } (
      map (nm: {
        "rclone-config-${nm.name}" = {
          description = "Generate rclone config for WebDAV ${nm.name}";

          unitConfig = lib.optionalAttrs (nm.m.encryptedPasswordFile != null) {
            # Decrypt using local identity; avoid relying on /run/agenix (tmpfs).
            RequiresMountsFor = [ "/home" ];
          };

          wantedBy = [ ];
          after = [ "local-fs.target" ];

          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = false;
            Environment = [ "HOME=/root" ];
          };

          script = ''
            set -euo pipefail
            umask 077

            conf=${lib.escapeShellArg nm.runConfigPath}
            tmp="$conf.tmp"

            RAW_PASS=""
            ${optionalString (nm.m.password != null) "RAW_PASS=${lib.escapeShellArg nm.m.password}"}
            ${optionalString (nm.m.encryptedPasswordFile != null) ''
              RAW_PASS="$(${pkgs.rage}/bin/rage -d ${identityArgs} ${lib.escapeShellArg nm.m.encryptedPasswordFile})"
            ''}

            OBS_PASS=$(${pkgs.rclone}/bin/rclone --config /dev/null obscure "$RAW_PASS")

            ${pkgs.coreutils}/bin/mkdir -p ${lib.escapeShellArg nm.runConfigDir}

            ${pkgs.coreutils}/bin/cat >"$tmp" <<EOF
            [${nm.name}]
            type = webdav
            url = ${nm.m.url}
            vendor = other
            ${optionalString (nm.m.username != null) "user = ${nm.m.username}"}
            pass = $OBS_PASS
            EOF

            ${pkgs.coreutils}/bin/chmod 600 "$tmp"
            ${pkgs.coreutils}/bin/mv -f "$tmp" "$conf"
          '';
        };
      }) normalizedMounts
    );

    # Mount definitions (system-wide visible) using mount.rclone.
    fileSystems = lib.listToAttrs (
      map (
        nm:
        let
          extraOptions = map nm.normalizeMountOption nm.m.extraOptions;
        in
        {
          name = nm.mp;
          value = {
            device = "${nm.name}:";
            fsType = "rclone";
            options = [
              "nodev"
              "nofail"
              "allow_other"
              "args2env"
              "config=${nm.runConfigPath}"
              "uid=${toString defaultUid}"
              "gid=${toString defaultGid}"
              "dir-perms=0755"
              "file-perms=0644"
              "x-systemd.requires=network-online.target"
              "x-systemd.after=network-online.target"
              "x-systemd.requires=rclone-config-${nm.name}.service"
              "x-systemd.after=rclone-config-${nm.name}.service"
            ]
            ++ lib.optionals (!nm.m.automount) [ "noauto" ]
            ++ lib.optionals nm.m.automount [
              "x-systemd.automount"
              "x-systemd.idle-timeout=60"
            ]
            ++ lib.optionals nm.m.readOnly [ "read-only" ]
            ++ lib.optionals nm.m.cache.enable ([
              "vfs-cache-mode=full"
              "vfs-cache-max-size=${toString nm.m.cache.sizeMiB}M"
              "vfs-cache-max-age=24h"
              "cache-dir=${nm.cacheDir}"
              "dir-cache-time=1m"
              "buffer-size=64M"
            ])
            ++ extraOptions;
          };
        }
      ) normalizedMounts
    );

    # Explicitly disable davfs2 since we are replacing it
    services.davfs2.enable = lib.mkForce false;

    # Remove user from davfs2 group if it exists
    # users.users.${defaultUserName}.extraGroups = lib.mkForce (lib.remove "davfs2" config.users.users.${defaultUserName}.extraGroups);
  };
}
