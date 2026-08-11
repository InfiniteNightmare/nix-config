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

  cfg = config.programs.nixosCleanSwitch;
  snapshotCfg = cfg.generationSnapshots;

  configuredLimit =
    if config.boot.loader.grub.enable && config.boot.loader.grub.configurationLimit != null then
      config.boot.loader.grub.configurationLimit
    else if
      config.boot.loader.systemd-boot.enable && config.boot.loader.systemd-boot.configurationLimit != null
    then
      config.boot.loader.systemd-boot.configurationLimit
    else
      cfg.fallbackConfigurationLimit;

  bootMount = config.boot.loader.efi.efiSysMountPoint;

  runtimePath = lib.makeBinPath [
    config.nix.package
    pkgs.coreutils
    pkgs.findutils
    pkgs.gawk
    pkgs.gnugrep
    pkgs.gnused
    pkgs.util-linux
  ];

  snapshotRuntimePath = lib.makeBinPath [
    pkgs.btrfs-progs
    pkgs.coreutils
    pkgs.findutils
    pkgs.gawk
    pkgs.jq
    pkgs.util-linux
  ];

  snapshotMembers = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: subvolume: "${name}\t${subvolume}") snapshotCfg.members
  );

  generationSnapshot = pkgs.writeShellScriptBin "nixos-generation-snapshot" ''
    export PATH=${lib.escapeShellArg snapshotRuntimePath}:$PATH
    export LC_ALL=C
    export SYSTEM_PROFILE=/nix/var/nix/profiles/system
    export SNAPSHOT_FILESYSTEM_MOUNT=${lib.escapeShellArg snapshotCfg.filesystemMount}
    export SNAPSHOT_STORAGE_SUBVOLUME=${lib.escapeShellArg snapshotCfg.storageSubvolume}
    export SNAPSHOT_MEMBERS=${lib.escapeShellArg snapshotMembers}

    exec ${pkgs.runtimeShell} ${../../scripts/nixos-generation-snapshot} "$@"
  '';

  generationSnapshotExe =
    if snapshotCfg.enable then "${generationSnapshot}/bin/nixos-generation-snapshot" else "";

  bootClean = pkgs.writeShellScriptBin "nixos-boot-clean" ''
    export PATH=${lib.escapeShellArg runtimePath}:$PATH
    export BOOT_MOUNT=${lib.escapeShellArg bootMount}
    export SYSTEM_PROFILE=/nix/var/nix/profiles/system
    export CONFIGURATION_LIMIT=${toString configuredLimit}
    export GC_OPTIONS=${lib.escapeShellArg config.nix.gc.options}
    export MIN_FREE_MIB=${toString cfg.minFreeMiB}
    export GENERATION_SNAPSHOT=${lib.escapeShellArg generationSnapshotExe}

    exec ${pkgs.runtimeShell} ${../../scripts/nixos-boot-clean} "$@"
  '';

  cleanSwitch = pkgs.writeShellScriptBin "nixos-clean-switch" ''
    export PATH=${lib.escapeShellArg runtimePath}:$PATH
    export BOOT_MOUNT=${lib.escapeShellArg bootMount}
    export SYSTEM_PROFILE=/nix/var/nix/profiles/system
    export CONFIGURATION_LIMIT=${toString configuredLimit}
    export GC_OPTIONS=${lib.escapeShellArg config.nix.gc.options}
    export MIN_FREE_MIB=${toString cfg.minFreeMiB}
    export FLAKE_REF=${lib.escapeShellArg "${cfg.flake}#${cfg.host}"}
    export NIXOS_REBUILD=/run/current-system/sw/bin/nixos-rebuild
    export BOOT_CLEAN=${bootClean}/bin/nixos-boot-clean
    export GENERATION_SNAPSHOT=${lib.escapeShellArg generationSnapshotExe}
    export CURRENT_SYSTEM=/run/current-system

    exec ${pkgs.runtimeShell} ${../../scripts/nixos-clean-switch} "$@"
  '';
in
{
  options.programs.nixosCleanSwitch = {
    enable = mkEnableOption "configuration-aware NixOS boot cleanup commands";

    flake = mkOption {
      type = types.str;
      default = "/etc/nixos";
      description = "Path to the flake used by nixos-clean-switch.";
    };

    host = mkOption {
      type = types.str;
      default = config.networking.hostName;
      description = "Flake NixOS configuration attribute used by nixos-clean-switch.";
    };

    fallbackConfigurationLimit = mkOption {
      type = types.ints.positive;
      default = 3;
      description = "Generation count used when the active bootloader has no configurationLimit.";
    };

    minFreeMiB = mkOption {
      type = types.ints.unsigned;
      default = 16;
      description = "Free MiB budget kept on the EFI system partition when estimating retained boot generations.";
    };

    generationSnapshots = {
      enable = mkEnableOption "Btrfs snapshot sets tied to NixOS system generations";

      filesystemMount = mkOption {
        type = types.str;
        default = "/";
        description = "Mounted Btrfs filesystem used to discover the top-level subvolume.";
      };

      storageSubvolume = mkOption {
        type = types.str;
        default = "@nixos-snapshots";
        description = "Top-level Btrfs subvolume dedicated to managed generation snapshots.";
      };

      members = mkOption {
        type = types.attrsOf types.str;
        default = {
          root = "@";
          home = "@home";
        };
        description = "Snapshot member names mapped to Btrfs top-level source subvolumes.";
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = lib.optionals snapshotCfg.enable [
      {
        assertion = lib.hasPrefix "/" snapshotCfg.filesystemMount;
        message = "programs.nixosCleanSwitch.generationSnapshots.filesystemMount must be absolute";
      }
      {
        assertion = snapshotCfg.members != { };
        message = "programs.nixosCleanSwitch.generationSnapshots.members must not be empty";
      }
      {
        assertion =
          let
            safeRelative =
              path:
              path != ""
              && !lib.hasPrefix "/" path
              && !lib.hasInfix "\n" path
              && !lib.hasInfix "\t" path
              && lib.all (component: component != "" && component != "." && component != "..") (
                lib.splitString "/" path
              );
          in
          safeRelative snapshotCfg.storageSubvolume
          && !lib.hasInfix "/" snapshotCfg.storageSubvolume
          && lib.all safeRelative (lib.attrValues snapshotCfg.members)
          &&
            lib.length (lib.attrValues snapshotCfg.members)
            == lib.length (lib.unique (lib.attrValues snapshotCfg.members))
          && lib.all (name: builtins.match "[A-Za-z0-9][A-Za-z0-9_-]*" name != null) (
            lib.attrNames snapshotCfg.members
          );
        message = "generation snapshot names and subvolumes must use safe relative paths";
      }
      {
        assertion =
          let
            pathsOverlap =
              first: second:
              first == second || lib.hasPrefix "${first}/" second || lib.hasPrefix "${second}/" first;
          in
          lib.all (member: !pathsOverlap snapshotCfg.storageSubvolume member) (
            lib.attrValues snapshotCfg.members
          );
        message = "generation snapshot storage must be disjoint from every source subvolume";
      }
      {
        assertion =
          let
            gcWords = lib.filter (word: word != "") (
              lib.splitString " " (lib.replaceStrings [ "\t" "\n" "\r" ] [ " " " " " " ] config.nix.gc.options)
            );
            deletesGenerations =
              word:
              word == "-d"
              || word == "--delete-old"
              || word == "--delete-older-than"
              || lib.hasPrefix "--delete-older-than=" word;
          in
          !lib.any deletesGenerations gcWords;
        message = "nix.gc.options must not delete profile generations when generation snapshots are enabled; use nixos-boot-clean so checkpoints are pruned in lockstep";
      }
    ];

    environment.systemPackages = [
      bootClean
      cleanSwitch
    ]
    ++ lib.optionals snapshotCfg.enable [
      generationSnapshot
    ];
  };
}
