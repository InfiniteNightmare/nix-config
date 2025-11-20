# Btrfs 快照到 NAS 的备份配置
# 使用 btrbk 将 Btrfs 快照增量同步到 btrfs NAS
#
# 针对 fnos NAS (10.214.131.20:2222)
# 备份路径：/vol2/1001/snapshots

{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.btrfsNasBackup;
in
{
  options.services.btrfsNasBackup = {
    enable = mkEnableOption "Btrfs 快照到 NAS 的自动备份";

    nasHost = mkOption {
      type = types.str;
      default = "10.214.131.20";
      description = "NAS 主机地址";
    };

    nasPort = mkOption {
      type = types.port;
      default = 2222;
      description = "NAS SSH 端口";
    };

    nasUser = mkOption {
      type = types.str;
      default = "charname";
      description = "NAS SSH 用户名";
    };

    sshKeyFile = mkOption {
      type = types.str;
      default = "/home/charname/.ssh/id_ed25519";
      description = "SSH 私钥文件路径";
    };

    backupBasePath = mkOption {
      type = types.str;
      default = "/vol2/1001/snapshots";
      description = "NAS 上的备份基础路径";
    };

    schedule = mkOption {
      type = types.str;
      default = "daily";
      description = "备份计划（systemd timer 格式）";
    };

    volumes = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            source = mkOption {
              type = types.str;
              description = "源 subvolume 路径";
              example = "/home";
            };

            targetName = mkOption {
              type = types.str;
              description = "目标目录名称";
              example = "home";
            };

            snapshotDir = mkOption {
              type = types.str;
              default = ".snapshots";
              description = "快照目录名称";
            };
          };
        }
      );
      default = {
        home = {
          source = "/home";
          targetName = "home";
        };
        root = {
          source = "/";
          targetName = "root";
        };
        data = {
          source = "/data";
          targetName = "data";
        };
      };
      description = "要备份的 volume 配置";
    };

    retention = {
      snapshot = mkOption {
        type = types.str;
        default = "14d 4w";
        description = "本地快照保留策略";
      };

      target = mkOption {
        type = types.str;
        default = "30d 12w 12m 2y";
        description = "NAS 备份保留策略";
      };
    };
  };

  config = mkIf cfg.enable {

    # 配置 root 用户的 SSH
    systemd.services.setup-btrbk-ssh = {
      description = "Setup SSH config for btrbk NAS backup";
      wantedBy = [ "multi-user.target" ];
      before = [ "btrbk-nas-backup.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
                # 创建 root 的 .ssh 目录
                mkdir -p /root/.ssh
                chmod 700 /root/.ssh

                # 复制用户的 SSH 密钥到 root
                if [ -f ${cfg.sshKeyFile} ]; then
                  cp ${cfg.sshKeyFile} /root/.ssh/nas_backup_key
                  cp ${cfg.sshKeyFile}.pub /root/.ssh/nas_backup_key.pub
                  chmod 600 /root/.ssh/nas_backup_key
                  chmod 644 /root/.ssh/nas_backup_key.pub
                fi

                # 创建 SSH 配置
                cat > /root/.ssh/config << EOF
        Host ${cfg.nasHost}
            Port ${toString cfg.nasPort}
            User ${cfg.nasUser}
            IdentityFile /root/.ssh/nas_backup_key
            StrictHostKeyChecking accept-new
            Compression yes
            ServerAliveInterval 30
            ServerAliveCountMax 3
        EOF
                chmod 600 /root/.ssh/config

                echo "SSH config for btrbk setup complete"
      '';
    };

    # btrbk 配置
    services.btrbk.instances.nas-backup = {
      onCalendar = cfg.schedule;

      settings = {
        # 快照保留策略
        snapshot_preserve = cfg.retention.snapshot;
        snapshot_preserve_min = "2d";

        # 备份目标保留策略
        target_preserve = cfg.retention.target;
        target_preserve_min = "7d";

        # 备份选项
        snapshot_create = "onchange";
        incremental = "yes";

        # SSH 配置
        ssh_identity = "/root/.ssh/nas_backup_key";
        ssh_user = cfg.nasUser;
        ssh_compression = "yes";
        ssh_cipher_spec = "chacha20-poly1305@openssh.com";

        # 传输速率限制（可选，避免占用太多带宽）
        # rate_limit = "10m";

        # 备份各个 volume (必须是绝对路径)
        # btrbk volume 格式: volume.<path> = { subvolume = ...; target = "ssh://host/path"; }
        volume = listToAttrs (
          map (
            name:
            let
              vol = cfg.volumes.${name};
            in
            nameValuePair vol.source {
              subvolume = ".";
              snapshot_dir = vol.snapshotDir;
              # SSH target: btrbk 会使用 ssh_user 和上面定义的 SSH 配置
              target = "ssh://${cfg.nasHost}${cfg.backupBasePath}/${vol.targetName}";
            }
          ) (attrNames cfg.volumes)
        );
      };
    };

    # 安装必要的软件包和测试脚本
    environment.systemPackages =
      with pkgs;
      [
        btrbk
        btrfs-progs
        openssh
      ]
      ++ [
        (pkgs.writeShellScriptBin "nas-backup-test" ''
          #!/usr/bin/env bash
          set -e

          echo "=== 测试 NAS 备份配置 ==="

          echo "1. 测试网络连接..."
          if ping -c 3 ${cfg.nasHost} &>/dev/null; then
            echo "  ✓ 网络连接正常"
          else
            echo "  ✗ 网络连接失败"
            exit 1
          fi

          echo "2. 测试 SSH 连接..."
          if ssh -p ${toString cfg.nasPort} -o ConnectTimeout=5 ${cfg.nasUser}@${cfg.nasHost} "echo 'SSH OK'" &>/dev/null; then
            echo "  ✓ SSH 连接成功"
          else
            echo "  ✗ SSH 连接失败"
            exit 1
          fi

          echo "3. 测试 SSH 密钥认证..."
          if ssh -p ${toString cfg.nasPort} -o PasswordAuthentication=no ${cfg.nasUser}@${cfg.nasHost} "echo 'OK'" &>/dev/null; then
            echo "  ✓ 密钥认证成功"
          else
            echo "  ✗ 密钥认证失败"
            exit 1
          fi

          echo "4. 检查 NAS 备份目录..."
          if ssh -p ${toString cfg.nasPort} ${cfg.nasUser}@${cfg.nasHost} "test -d ${cfg.backupBasePath}"; then
            echo "  ✓ 备份基础目录存在: ${cfg.backupBasePath}"
          else
            echo "  ✗ 备份目录不存在，正在创建..."
            ssh -p ${toString cfg.nasPort} ${cfg.nasUser}@${cfg.nasHost} "mkdir -p ${cfg.backupBasePath}"
            echo "  ✓ 已创建备份目录"
          fi

          echo "5. 检查 NAS btrfs 支持..."
          if ssh -p ${toString cfg.nasPort} ${cfg.nasUser}@${cfg.nasHost} "which btrfs" &>/dev/null; then
            echo "  ✓ NAS 支持 btrfs"
            ssh -p ${toString cfg.nasPort} ${cfg.nasUser}@${cfg.nasHost} "btrfs --version"
          else
            echo "  ✗ NAS 不支持 btrfs"
            exit 1
          fi

          echo "6. 检查备份服务状态..."
          systemctl status btrbk-nas-backup.timer --no-pager || true

          echo ""
          echo "=== 测试完成 ==="
          echo "所有检查通过！可以开始备份。"
          echo ""
          echo "下一步："
          echo "  sudo systemctl start btrbk-nas-backup.service  # 手动触发备份"
          echo "  sudo journalctl -u btrbk-nas-backup.service -f  # 查看备份日志"
        '')

        (pkgs.writeShellScriptBin "nas-backup-status" ''
          #!/usr/bin/env bash

          echo "=== NAS 备份状态 ==="
          echo ""

          echo "本地快照："
          ${concatStringsSep "\n" (
            mapAttrsToList (name: vol: ''
              echo "  ${vol.source}:"
              if [ -d "${vol.source}/${vol.snapshotDir}" ]; then
                ls -1 ${vol.source}/${vol.snapshotDir} | wc -l | xargs echo "    快照数量:"
              else
                echo "    快照目录不存在"
              fi
            '') cfg.volumes
          )}

          echo ""
          echo "NAS 备份："
          ${concatStringsSep "\n" (
            mapAttrsToList (name: vol: ''
              echo "  ${vol.targetName}:"
              ssh -p ${toString cfg.nasPort} ${cfg.nasUser}@${cfg.nasHost} \
                "if [ -d ${cfg.backupBasePath}/${vol.targetName} ]; then \
                   ls -1 ${cfg.backupBasePath}/${vol.targetName} 2>/dev/null | wc -l | xargs echo '    备份快照数量:'; \
                 else \
                   echo '    备份目录不存在'; \
                 fi" || echo "    无法连接 NAS"
            '') cfg.volumes
          )}

          echo ""
          echo "定时器状态："
          systemctl status btrbk-nas-backup.timer --no-pager | grep -E "(Active|Trigger)"

          echo ""
          echo "最近的备份日志："
          journalctl -u btrbk-nas-backup.service --since "24 hours ago" --no-pager | tail -20
        '')

        (pkgs.writeShellScriptBin "nas-backup-manual" ''
          #!/usr/bin/env bash

          echo "=== 手动触发 NAS 备份 ==="
          echo ""
          echo "开始备份..."

          sudo systemctl start btrbk-nas-backup.service

          echo ""
          echo "查看备份进度（Ctrl+C 退出）："
          sudo journalctl -u btrbk-nas-backup.service -f
        '')
      ];

    # 备份完成后的通知（可选）
    systemd.services.btrbk-nas-backup = {
      serviceConfig = {
        # 备份完成后记录日志
        ExecStartPost = pkgs.writeShellScript "btrbk-success" ''
          echo "NAS 备份成功完成 at $(date)" >> /var/log/nas-backup.log
          # 可以在这里添加通知，例如：
          # ${pkgs.curl}/bin/curl -fsS -m 10 "https://hc-ping.com/YOUR-UUID"
        '';
      };
    };

    # 创建日志文件
    systemd.tmpfiles.rules = [
      "f /var/log/nas-backup.log 0644 root root -"
    ];

    # 提示信息
    warnings = optional (cfg.volumes == { }) ''
      btrfsNasBackup 已启用但没有配置任何 volume。
      请在 services.btrfsNasBackup.volumes 中添加配置。
    '';

    assertions = [
      {
        assertion = cfg.nasHost != "";
        message = "必须配置 nasHost";
      }
      {
        assertion = cfg.backupBasePath != "";
        message = "必须配置 backupBasePath";
      }
      # SSH 密钥文件存在性在运行时通过 setup-btrbk-ssh 服务检查
    ];
  };
}
