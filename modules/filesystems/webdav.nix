{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkOption
    mkIf
    types
    optional
    mkAfter
    mapAttrsToList
    concatLists
    filter
    ;
  cfg = config.filesystems.webdav;

  mountSubmodule =
    { config, ... }:
    let
      mCfg = config;
    in
    {
      options = {
        url = mkOption {
          type = types.str;
          description = "WebDAV endpoint URL.";
        };
        mountPoint = mkOption {
          type = types.str;
          description = "Local mount point for this WebDAV share.";
        };
        username = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Username for Basic auth (null if no auth).";
        };
        password = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Inline password (plain text). Mutually exclusive with passwordAgenixSecret.";
        };
        passwordAgenixSecret = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "webdav-password";
          description = ''
            Name of an agenix (ragenix) secret (config.age.secrets.<name>) containing ONLY the password.
            If set, password must be null. The secret's content will be read at activation to compose /etc/davfs2/secrets.
          '';
        };
        useLocks = mkOption {
          type = types.bool;
          default = false;
          description = "Whether to enable WebDAV locking for this mount (overrides global default).";
        };
        extraMountOptions = mkOption {
          type = types.listOf types.str;
          default = [ "rw" ];
          description = "Extra mount options for this mount.";
        };
        createMountPoint = mkOption {
          type = types.bool;
          default = true;
          description = "Create mount directory via tmpfiles.";
        };
        automount = mkOption {
          type = types.bool;
          default = false;
          description = "Enable systemd automount (adds noauto,x-systemd.automount,_netdev if not already present).";
        };
      };

      config = {
        _module.assertions = [
          {
            assertion = (mCfg.password == null) || (mCfg.passwordAgenixSecret == null);
            message = "For mount ${mCfg.mountPoint}, define either password or passwordAgenixSecret, not both.";
          }
          {
            assertion = (mCfg.password == null && mCfg.passwordAgenixSecret == null) || (mCfg.username != null);
            message = "If password or passwordAgenixSecret is set, username must also be set.";
          }
        ];
      };
    };

  # Build effective mount list (legacy single options + new list).
  legacyMount =
    if cfg.url != null then
      [
        {
          url = cfg.url;
          mountPoint = cfg.mountPoint;
          username = cfg.username;
          password = cfg.password;
          passwordAgenixSecret = null;
          useLocks = cfg.useLocks;
          extraMountOptions = cfg.extraMountOptions;
          createMountPoint = cfg.createMountPoint;
          automount = cfg.automount;
        }
      ]
    else
      [ ];

  effectiveMounts = cfg.mounts ++ legacyMount;

  automountAdjustedOptions =
    m:
    let
      base = m.extraMountOptions;
      needNet = !(builtins.any (o: o == "_netdev") base);
      withNet = if needNet then base ++ [ "_netdev" ] else base;
      hasNoauto = builtins.any (o: o == "noauto") withNet;
      hasAutomount = builtins.any (o: o == "x-systemd.automount") withNet;
      withNoauto = if hasNoauto then withNet else withNet ++ [ "noauto" ];
      withAutomount = if hasAutomount then withNoauto else withNoauto ++ [ "x-systemd.automount" ];
    in
    if m.automount then withAutomount else base;

  anyLocks = builtins.any (m: m.useLocks) effectiveMounts;

  mountsNeedingDir = filter (m: m.createMountPoint) effectiveMounts;

  mountsWithInlineCreds = filter (m: m.username != null && m.password != null) effectiveMounts;
  mountsWithSecretCreds = filter (
    m: m.username != null && m.password == null && m.passwordAgenixSecret != null
  ) effectiveMounts;

  secretsScriptLines = concatLists [
    (map (
      m: "echo '${m.url} ${m.username} ${m.password}' >> /etc/davfs2/secrets"
    ) mountsWithInlineCreds)
    (map (m: ''
      printf '%s %s ' '${m.url}' '${m.username}' >> /etc/davfs2/secrets
      # Append secret (strip trailing newline)
      tr -d '\n' < "${config.age.secrets.${m.passwordAgenixSecret}.path}" >> /etc/davfs2/secrets
      echo >> /etc/davfs2/secrets
    '') mountsWithSecretCreds)
  ];

  secretsScript = builtins.concatStringsSep "\n" secretsScriptLines;

in
{
  options.filesystems.webdav = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable WebDAV (davfs2) mounting support.";
    };

    # Legacy single-mount options (still usable).
    url = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "http://example.com:5005";
      description = "LEGACY: Single WebDAV endpoint URL. Prefer filesystems.webdav.mounts.";
    };
    username = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "LEGACY: Username for single mount.";
    };
    password = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "LEGACY: Inline password for single mount.";
    };
    mountPoint = mkOption {
      type = types.str;
      default = "/mnt/webdav";
      description = "LEGACY: Mount point for single mount.";
    };
    useLocks = mkOption {
      type = types.bool;
      default = false;
      description = "LEGACY: Lock usage for single mount.";
    };
    extraMountOptions = mkOption {
      type = types.listOf types.str;
      default = [ "rw" ];
      description = "LEGACY: Extra mount options for single mount.";
    };
    createMountPoint = mkOption {
      type = types.bool;
      default = true;
      description = "LEGACY: Create mount point directory for single mount.";
    };
    automount = mkOption {
      type = types.bool;
      default = false;
      description = "LEGACY: Enable automount for single mount.";
    };

    # New multi-mount interface.
    mounts = mkOption {
      type = types.listOf (types.submodule mountSubmodule);
      default = [ ];
      description = ''
        List of WebDAV mount definitions.
        Each item: { url, mountPoint, username?, password?, passwordAgenixSecret?,
                     useLocks?, extraMountOptions?, createMountPoint?, automount? }.
        If automount = true then "noauto","x-systemd.automount","_netdev" are ensured.
      '';
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = effectiveMounts != [ ];
        message = "filesystems.webdav.enable = true but neither legacy fields nor mounts are defined.";
      }
      {
        assertion = (cfg.password == null) || (cfg.username != null);
        message = "Legacy single mount: if password is set, username must also be set.";
      }
    ];

    services.davfs2 = {
      enable = true;
      settings.globalSection.use_locks = anyLocks;
    };

    # Generate fileSystems entries
    fileSystems =
      let
        makeFS = m: {
          "${m.mountPoint}" = {
            device = m.url;
            fsType = "davfs";
            options = automountAdjustedOptions m;
          };
        };
        mapped = map makeFS effectiveMounts;
      in
      lib.foldl' lib.recursiveUpdate { } mapped;

    # Directories
    systemd.tmpfiles.rules = map (m: "d ${m.mountPoint} 0755 root root -") mountsNeedingDir;

    # Secrets assembly (only if any credentials present)
    system.activationScripts.webdavDavfs2Secrets =
      mkIf ((mountsWithInlineCreds != [ ]) || (mountsWithSecretCreds != [ ]))
        {
          deps = [ "agenix" ];
          text = ''
                    echo "Generating /etc/davfs2/secrets for WebDAV mounts..."
                    install -d -m 0755 /etc/davfs2
                    : > /etc/davfs2/secrets
                    chmod 600 /etc/davfs2/secrets
            ${secretsScript}
          '';
        };

    # Append user group if user exists
    users.users.charname.extraGroups = mkIf (config.users.users ? charname) (mkAfter [ "davfs2" ]);
  };
}
