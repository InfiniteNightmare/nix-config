{
  lib,
  config,
  pkgs,
  ...
}:
#
# Simplified WebDAV (davfs2) multi‑mount module
#
# Goals:
#  - Minimal host‑side configuration: just declare mounts.{name}.url (+ auth)
#  - Automatic sensible defaults (mount points, automount, cache, uid/gid, modes)
#  - Support age (agenix / ragenix) secrets via `secret` (name of age.secrets.<secret>)
#  - Optional inline password (discouraged) via `password`
#  - Per‑mount override of a few simple booleans / numbers
#
# Host usage example:
#
# filesystems.webdav = {
#   enable = true;
#   mounts = {
#     fnos = {
#       url = "http://10.214.131.20:5005";
#       username = "charname";
#       secret = "webdav-password";   # age.secrets.webdav-password
#       # mountPoint = "/mnt/fnos";   # (default /mnt/<name>)
#       # readOnly = false;
#       # cache.enable = true;
#       # cache.sizeMiB = 100;
#       # automount = true;
#     };
#   };
# };
#
# Provided options (per mount):
#   url (required)               : WebDAV endpoint
#   username (optional)          : Required if secret/password used
#   secret (optional)            : age secret name (exclusive with password)
#   password (optional)          : inline plain password (exclusive with secret)
#   mountPoint (optional)        : default /mnt/<mountName>
#   readOnly (bool)              : default false
#   automount (bool)             : default true (adds noauto,x-systemd.automount,_netdev)
#   cache.enable (bool)          : default true
#   cache.sizeMiB (int)          : default 100
#   cache.baseDir (str)          : default /var/cache/davfs
#   extraOptions (list of str)   : appended raw davfs options
#
# Automatically added mount options:
#   rw/ro, uid/gid (best-effort), file_mode=0644, dir_mode=0755,
#   cache_dir=..., cache_size=..., and automount helpers.
#
# NOTE: We attempt to determine a user to own files (uid/gid). By default we
# look for a user named "charname"; if absent / uid unknown we fallback to 1000/100.
#
let
  inherit (lib)
    mkEnableOption
    mkOption
    mkIf
    types
    optional
    optionalString
    concatMapStringsSep
    ;

  cfg = config.filesystems.webdav;

  # Heuristic defaults for ownership (kept simple).
  defaultUserName = "charname";
  defaultUid =
    let
      users = config.users.users;
    in
    if builtins.hasAttr defaultUserName users && (users.${defaultUserName} ? uid) then
      users.${defaultUserName}.uid
    else
      1000;

  # There is no guaranteed primary group id exposed unless explicitly set;
  # we default to the conventional "users" = 100.
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
          description = "Username for authentication (required if secret/password is set).";
        };
        secret = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Name of an age secret (config.age.secrets.<name>) with ONLY the password (mutually exclusive with password).";
        };
        password = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Inline plain password (discouraged) (mutually exclusive with secret).";
        };
        mountPoint = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Override mount point (default /mnt/<name>).";
        };
        readOnly = mkOption {
          type = types.bool;
          default = false;
          description = "Mount read-only (ro) if true, else rw.";
        };
        automount = mkOption {
          type = types.bool;
          default = true;
          description = "Enable systemd automount (adds noauto,x-systemd.automount,_netdev).";
        };
        cache = {
          enable = mkOption {
            type = types.bool;
            default = true;
            description = "Enable davfs2 local caching.";
          };
          sizeMiB = mkOption {
            type = types.int;
            default = 100;
            description = "Cache size in MiB (when cache.enable = true).";
          };
          baseDir = mkOption {
            type = types.str;
            default = "/var/cache/davfs";
            description = "Base directory for per-mount cache subdirectories.";
          };
        };
        extraOptions = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Extra raw davfs mount options to append.";
        };
      };
    };

  # Convert attrset of mounts to a normalized list with computed fields.
  normalizedMounts = lib.mapAttrsToList (
    name: m:
    let
      mp = if m.mountPoint == null then "/mnt/${name}" else m.mountPoint;
      cacheDir = if m.cache.enable then "${m.cache.baseDir}/${name}" else null;
      baseOpts = [
        (if m.readOnly then "ro" else "rw")
        "uid=${toString defaultUid}"
        "gid=${toString defaultGid}"
        "file_mode=0644"
        "dir_mode=0755"
      ]
      ++ lib.optional (cacheDir != null) "cache_dir=${cacheDir}"
      ++ lib.optional (cacheDir != null) "cache_size=${toString m.cache.sizeMiB}"
      ++ m.extraOptions;

      autoOpts =
        if m.automount then
          baseOpts
          ++ [
            "_netdev"
            "noauto"
            "x-systemd.automount"
          ]
        else
          baseOpts;
    in
    {
      name = name;
      url = m.url;
      mountPoint = mp;
      username = m.username;
      secret = m.secret;
      password = m.password;
      cacheDir = cacheDir;
      options = autoOpts;
    }
  ) cfg.mounts;

  anySecrets = lib.any (
    m: (m.username != null) && (m.password != null || m.secret != null)
  ) normalizedMounts;

  # Generate lines for secrets (inline password mounts).
  inlineSecretLines = concatMapStringsSep "\n" (
    m:
    if m.username != null && m.password != null then
      "echo '${m.url} ${m.username} ${m.password}' >> /etc/davfs2/secrets"
    else
      ""
  ) normalizedMounts;

  # Generate lines for age secret mounts (defer reading secret file).
  ageSecretLines = concatMapStringsSep "\n" (
    m:
    if m.username != null && m.password == null && m.secret != null then
      ''
        printf '%s %s ' '${m.url}' '${m.username}' >> /etc/davfs2/secrets
        tr -d '\n' < "${config.age.secrets.${m.secret}.path}" >> /etc/davfs2/secrets
        echo >> /etc/davfs2/secrets
      ''
    else
      ""
  ) normalizedMounts;

in
{
  options.filesystems.webdav = {
    enable = mkEnableOption "Simplified WebDAV multi-mount management (davfs2)";
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
    ++ map (m: {
      assertion = m.url != "";
      message = "webdav mount ${m.mountPoint}: url cannot be empty.";
    }) normalizedMounts
    ++ map (m: {
      assertion = !(m.password != null && m.secret != null);
      message = "webdav mount ${m.mountPoint}: cannot set both password and secret.";
    }) normalizedMounts
    ++ map (m: {
      assertion = (m.password == null && m.secret == null) || (m.username != null);
      message = "webdav mount ${m.mountPoint}: username required when password or secret provided.";
    }) normalizedMounts;

    services.davfs2.enable = true;

    fileSystems = lib.foldl' lib.recursiveUpdate { } (
      map (m: {
        "${m.mountPoint}" = {
          device = m.url;
          fsType = "davfs";
          options = m.options;
        };
      }) normalizedMounts
    );

    systemd.tmpfiles.rules =
      (map (m: "d ${m.mountPoint} 0755 root root -") normalizedMounts)
      ++ (map (m: "d ${m.cacheDir} 0700 ${defaultUserName} users -") (
        lib.filter (m: m.cacheDir != null) normalizedMounts
      ));

    system.activationScripts.webdavDavfs2Secrets = mkIf anySecrets {
      deps = [ "agenix" ];
      text = ''
        install -d -m 755 /etc/davfs2
        : > /etc/davfs2/secrets
        chmod 600 /etc/davfs2/secrets
        ${inlineSecretLines}
        ${ageSecretLines}
      '';
    };

    users.users.${defaultUserName}.extraGroups = mkIf (config.users.users ? ${defaultUserName}) (
      lib.mkAfter [ "davfs2" ]
    );
  };
}
