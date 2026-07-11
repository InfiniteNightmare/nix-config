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

  bootClean = pkgs.writeShellScriptBin "nixos-boot-clean" ''
    export PATH=${lib.escapeShellArg runtimePath}:$PATH
    export BOOT_MOUNT=${lib.escapeShellArg bootMount}
    export SYSTEM_PROFILE=/nix/var/nix/profiles/system
    export CONFIGURATION_LIMIT=${toString configuredLimit}
    export GC_OPTIONS=${lib.escapeShellArg config.nix.gc.options}
    export MIN_FREE_MIB=${toString cfg.minFreeMiB}

    exec ${pkgs.runtimeShell} ${../scripts/nixos-boot-clean} "$@"
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

    exec ${pkgs.runtimeShell} ${../scripts/nixos-clean-switch} "$@"
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
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [
      bootClean
      cleanSwitch
    ];
  };
}
