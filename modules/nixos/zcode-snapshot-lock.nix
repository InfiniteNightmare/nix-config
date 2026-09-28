{
  lib,
  config,
  pkgs,
  ...
}:
# Block ZCode's silent workspace-snapshot upload.
#
# The ZCode desktop client unconditionally packs the whole workspace,
# including full .git history, into ~/.zcode/v2/checkpoints and pushes it
# to cloud object storage with a server-held key. It repacks after the
# directory is deleted and exposes no setting to disable the pipeline
# (https://blog.ferstar.org/posts/zcode-silent-workspace-snapshot-upload/),
# so the only reliable block is kernel-level: an immutable staging
# directory makes artifact creation — and therefore upload — impossible.
#
# Trade-off: the client's checkpoint-rollback/timeline feature breaks;
# chat, completion and tool calls are unaffected. Lift manually with
# `chattr -i <dir>` (e2fsprogs is added to systemPackages below).

let
  inherit (lib)
    mkEnableOption
    mkOption
    mkIf
    types
    ;

  cfg = config.services.zcode-snapshot-lock;

  homeDir = "/home/${cfg.user}";
in
{
  options.services.zcode-snapshot-lock = {
    enable = mkEnableOption "kernel-level lock on ZCode's snapshot staging directory";

    user = mkOption {
      type = types.str;
      default = "charname";
      description = "User account whose ZCode state directory should be locked.";
    };
  };

  config = mkIf cfg.enable {
    # NixOS ships no chattr/lsattr in PATH; keep them available so the lock
    # can be inspected and lifted by hand.
    environment.systemPackages = [ pkgs.e2fsprogs ];

    systemd.services.zcode-snapshot-lock = {
      description = "Lock ZCode workspace-snapshot staging directory";
      wantedBy = [ "multi-user.target" ];
      after = [ "local-fs.target" ];
      serviceConfig.Type = "oneshot";

      script = ''
        set -eu

        parent=${homeDir}/.zcode/v2
        dir=$parent/checkpoints
        # No ZCode state directory means the client was never used here.
        [ -d "$parent" ] || exit 0

        ${pkgs.coreutils}/bin/install -d -m 0755 -o ${cfg.user} -g users "$dir"

        # Anything sitting in an unlocked directory is a snapshot artifact the
        # client will upload once it can, so wipe it before re-locking. The
        # immutable flag keeps the directory permanently empty, so any content
        # proves the lock lapsed at some point.
        flags=$(${pkgs.e2fsprogs}/bin/lsattr -d "$dir" | ${pkgs.coreutils}/bin/cut -d' ' -f1)
        case "$flags" in
          *i*) ;;
          *) ${pkgs.findutils}/bin/find "$dir" -mindepth 1 -delete ;;
        esac

        ${pkgs.e2fsprogs}/bin/chattr +i "$dir"
      '';
    };
  };
}
