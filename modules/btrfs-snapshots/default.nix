# Btrfs 自动快照配置模块
# 使用 snapper 进行快照管理，包括：
# 1. 定时快照（timeline snapshots）
# 2. NixOS generation 切换时自动快照
# 3. 快照保留策略和自动清理

{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.btrfsSnapshots;
in
{
  imports = [
    ./nas-backup.nix
  ];

  options.services.btrfsSnapshots = {
    enable = mkEnableOption "Btrfs 自动快照服务";

    configs = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            subvolume = mkOption {
              type = types.str;
              description = "要快照的 subvolume 挂载点";
              example = "/";
            };

            extraConfig = mkOption {
              type = types.lines;
              default = "";
              description = "额外的 snapper 配置";
            };
          };
        }
      );
      default = { };
      description = "Snapper 配置集";
    };

    snapshotOnBoot = mkOption {
      type = types.bool;
      default = true;
      description = "在系统启动时创建快照";
    };

    snapshotOnRebuild = mkOption {
      type = types.bool;
      default = true;
      description = "在 nixos-rebuild 时创建快照（通过 activation script）";
    };

    timeline = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "启用定时快照";
      };

      # 保留策略
      limits = {
        hourly = mkOption {
          type = types.int;
          default = 24;
          description = "保留的小时快照数量";
        };

        daily = mkOption {
          type = types.int;
          default = 7;
          description = "保留的每日快照数量";
        };

        weekly = mkOption {
          type = types.int;
          default = 4;
          description = "保留的每周快照数量";
        };

        monthly = mkOption {
          type = types.int;
          default = 6;
          description = "保留的每月快照数量";
        };

        yearly = mkOption {
          type = types.int;
          default = 2;
          description = "保留的每年快照数量";
        };
      };
    };
  };

  config = mkIf cfg.enable {
    # 安装必要的软件包
    environment.systemPackages = with pkgs; [
      snapper
      snapper-gui # 可选：GUI 工具
      btrfs-progs
    ];

    # 初始化 snapper 配置
    systemd.services.snapper-init = {
      description = "Initialize snapper configurations";
      wantedBy = [ "multi-user.target" ];
      before = [
        "snapper-timeline.timer"
        "snapper-cleanup.timer"
        "snapper-boot.service"
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        ${concatStringsSep "\n" (
          mapAttrsToList (name: snapConfig: ''
            # 检查配置是否存在
            if ! ${pkgs.snapper}/bin/snapper -c ${name} list &>/dev/null; then
              echo "Creating snapper config for ${name} (${snapConfig.subvolume})"

              # 创建 .snapshots subvolume（如果不存在）
              if [ ! -d "${snapConfig.subvolume}/.snapshots" ]; then
                ${pkgs.btrfs-progs}/bin/btrfs subvolume create "${snapConfig.subvolume}/.snapshots" || true
              fi

              # 创建 snapper 配置
              ${pkgs.snapper}/bin/snapper -c ${name} create-config "${snapConfig.subvolume}" || true

              # 设置权限
              chmod 750 "${snapConfig.subvolume}/.snapshots" || true
            fi
          '') cfg.configs
        )}

        echo "Snapper initialization complete"
      '';
    };

    # 配置 snapper
    services.snapper = {
      configs = mapAttrs (
        name: snapConfig:
        {
          SUBVOLUME = snapConfig.subvolume;

          # 允许普通用户查看快照
          ALLOW_USERS = [ config.users.users.charname.name or "charname" ];

          # 时间线快照配置
          TIMELINE_CREATE = cfg.timeline.enable;
          TIMELINE_CLEANUP = cfg.timeline.enable;

          # 保留策略
          TIMELINE_LIMIT_HOURLY = toString cfg.timeline.limits.hourly;
          TIMELINE_LIMIT_DAILY = toString cfg.timeline.limits.daily;
          TIMELINE_LIMIT_WEEKLY = toString cfg.timeline.limits.weekly;
          TIMELINE_LIMIT_MONTHLY = toString cfg.timeline.limits.monthly;
          TIMELINE_LIMIT_YEARLY = toString cfg.timeline.limits.yearly;

          # 空间管理
          SPACE_LIMIT = "0.5"; # 快照最多占用 50% 空间
          FREE_LIMIT = "0.2"; # 保持至少 20% 空闲空间

          # 其他配置
          SYNC_ACL = true;
          EMPTY_PRE_POST_CLEANUP = true;
        }
        // (
          if snapConfig.extraConfig != "" then
            {
              EXTRA_CONFIG = snapConfig.extraConfig;
            }
          else
            { }
        )
      ) cfg.configs;

      # 在系统启动时创建快照
      snapshotRootOnBoot = cfg.snapshotOnBoot;

      # 启用时间线快照的定时器
      # snapper 自带 systemd timer：snapper-timeline.timer 和 snapper-cleanup.timer
    };

    # NixOS rebuild 时自动创建快照
    # 这会在切换到新 generation 之前创建快照
    system.activationScripts.snapshotBeforeRebuild = mkIf cfg.snapshotOnRebuild {
      text = ''
        echo "Creating Btrfs snapshots before system activation..."

        ${concatStringsSep "\n" (
          mapAttrsToList (name: snapConfig: ''
            # 为 ${name} 创建快照
            if ${pkgs.snapper}/bin/snapper -c ${name} list &>/dev/null; then
              ${pkgs.snapper}/bin/snapper -c ${name} create \
                --description "pre-nixos-rebuild" \
                --cleanup-algorithm number \
                --userdata "important=yes" || true
            fi
          '') cfg.configs
        )}

        echo "Snapshots created successfully"
      '';
      deps = [ ];
    };

    # snapper 内置的 systemd 服务会自动创建
    # snapper-timeline.timer 和 snapper-cleanup.timer
    # 不需要手动定义，避免冲突

    # 提示信息
    warnings = optional (
      cfg.configs == { }
    ) "btrfsSnapshots 已启用但没有配置任何 subvolume。请在 services.btrfsSnapshots.configs 中添加配置。";
  };
}
