# 配置参考手册

## services.btrfsSnapshots

本地 Btrfs 快照配置

### 基础选项

| 选项 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `enable` | bool | `false` | 启用本地快照 |
| `snapshotOnRebuild` | bool | `false` | NixOS rebuild 时自动创建快照 |
| `snapshotOnBoot` | bool | `false` | 系统启动时创建快照 |

### 时间线快照

```nix
timeline = {
  enable = true;  # 启用定时快照
  limits = {
    hourly = 24;   # 保留 24 个小时快照
    daily = 7;     # 保留 7 个每日快照
    weekly = 4;    # 保留 4 个每周快照
    monthly = 6;   # 保留 6 个每月快照
    yearly = 2;    # 保留 2 个每年快照
  };
};
```

### Subvolume 配置

```nix
configs = {
  root = {
    subvolume = "/";
    snapshotDir = ".snapshots";  # 可选，默认值
  };
  home = {
    subvolume = "/home";
  };
  data = {
    subvolume = "/data";
  };
};
```

### 完整示例

```nix
services.btrfsSnapshots = {
  enable = true;
  snapshotOnRebuild = true;
  snapshotOnBoot = true;
  
  timeline = {
    enable = true;
    limits = {
      hourly = 24;
      daily = 7;
      weekly = 4;
      monthly = 6;
      yearly = 2;
    };
  };
  
  configs = {
    root.subvolume = "/";
    home.subvolume = "/home";
    data.subvolume = "/data";
  };
};
```

---

## services.btrfsNasBackup

NAS 远程备份配置（使用 btrbk）

### 基础选项

| 选项 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `enable` | bool | `false` | 启用 NAS 备份 |
| `nasHost` | string | `"10.214.131.20"` | NAS IP 地址 |
| `nasPort` | int | `2222` | SSH 端口 |
| `nasUser` | string | `"charname"` | SSH 用户名 |
| `sshKeyFile` | string | - | SSH 私钥路径 |
| `backupBasePath` | string | `"/vol2/1001/snapshots"` | NAS 上的备份路径 |
| `schedule` | string | `"daily"` | 备份频率 (systemd timer 格式) |

### 卷配置

默认值（无需手动配置）：

```nix
volumes = {
  home = {
    source = "/home";
    targetName = "home";
    snapshotDir = ".snapshots";
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
```

自定义卷：

```nix
volumes = {
  custom = {
    source = "/mnt/custom";
    targetName = "custom";
    snapshotDir = ".snapshots";
  };
};
```

### 保留策略

```nix
retention = {
  snapshot = "14d 4w";          # 本地快照: 14 天 + 4 周
  target = "30d 12w 12m 2y";    # NAS 备份: 30 天 + 12 周 + 12 月 + 2 年
};
```

格式说明：
- `d` = 天 (days)
- `w` = 周 (weeks)
- `m` = 月 (months)
- `y` = 年 (years)

### 完整示例

```nix
services.btrfsNasBackup = {
  enable = true;
  
  # NAS 连接配置
  nasHost = "10.214.131.20";
  nasPort = 2222;
  nasUser = "charname";
  sshKeyFile = "/home/charname/.ssh/id_ed25519";
  backupBasePath = "/vol2/1001/snapshots";
  
  # 备份计划
  schedule = "daily";  # 或 "hourly", "weekly", "03:00" 等
  
  # 保留策略（可选，使用默认值）
  retention = {
    snapshot = "14d 4w";
    target = "30d 12w 12m 2y";
  };
  
  # volumes 使用默认值，无需配置
};
```

---

## 高级配置

### 自定义备份时间

```nix
schedule = "03:00";  # 每天凌晨 3 点
schedule = "hourly"; # 每小时
schedule = "weekly"; # 每周
```

### 修改保留策略

更激进（节省空间）：

```nix
timeline.limits = {
  hourly = 12;   # 12 小时
  daily = 3;     # 3 天
  weekly = 2;    # 2 周
  monthly = 3;   # 3 月
  yearly = 1;    # 1 年
};
```

更保守（更多恢复点）：

```nix
timeline.limits = {
  hourly = 48;   # 2 天
  daily = 14;    # 2 周
  weekly = 8;    # 2 月
  monthly = 12;  # 1 年
  yearly = 5;    # 5 年
};
```

### 排除某些 subvolume

只快照特定分区：

```nix
configs = {
  home.subvolume = "/home";  # 只快照 home
};
```

---

## 工具和命令

### 本地快照管理

```bash
# 别名命令
snap-ls          # snapper -c all list
snap-home        # snapper -c home list
snap-root        # snapper -c root list
snap-status      # 查看快照状态摘要
snap-du          # 查看快照占用空间
snap-cleanup     # 清理旧快照

# snapshot-manager 工具
snapshot-manager status
snapshot-manager list home
snapshot-manager create home "描述"
snapshot-manager rollback home 42
snapshot-manager diff home 10 15
snapshot-manager disk-usage
```

### NAS 备份管理

```bash
# 测试和状态
nas-backup-test      # 测试 NAS 连接、SSH、btrfs 支持等
nas-backup-status    # 查看本地和 NAS 快照数量、最近备份日志
nas-backup-manual    # 手动触发备份并显示实时日志

# systemd 服务
sudo systemctl status btrbk-nas-backup.timer
sudo systemctl start btrbk-nas-backup.service
sudo journalctl -u btrbk-nas-backup.service -f
```

---

## 常见配置场景

### 场景 1: 仅本地快照

```nix
services.btrfsSnapshots = {
  enable = true;
  snapshotOnRebuild = true;
  timeline.enable = true;
  configs = {
    home.subvolume = "/home";
  };
};
```

### 场景 2: 本地快照 + NAS 备份

```nix
services.btrfsSnapshots = {
  enable = true;
  snapshotOnRebuild = true;
  timeline.enable = true;
  configs = {
    root.subvolume = "/";
    home.subvolume = "/home";
  };
};

services.btrfsNasBackup = {
  enable = true;
  nasHost = "192.168.1.100";
  nasPort = 22;
  nasUser = "backup";
  sshKeyFile = "/root/.ssh/nas_key";
  backupBasePath = "/backup/laptop";
};
```

### 场景 3: 频繁快照 + 快速备份

```nix
services.btrfsSnapshots = {
  enable = true;
  snapshotOnRebuild = true;
  timeline = {
    enable = true;
    limits = {
      hourly = 48;  # 2 天
      daily = 14;   # 2 周
      weekly = 4;
      monthly = 6;
      yearly = 2;
    };
  };
  configs = {
    home.subvolume = "/home";
  };
};

services.btrfsNasBackup = {
  enable = true;
  nasHost = "nas.local";
  schedule = "hourly";  # 每小时备份
  # ... 其他配置
};
```

---

## 故障排除

### 快照服务未运行

```bash
sudo systemctl start snapper-timeline.timer
sudo systemctl enable snapper-timeline.timer
```

### NAS 备份失败

检查：
1. SSH 连接: `ssh -p 2222 user@nas`
2. btrfs 支持: `ssh -p 2222 user@nas "which btrfs"`
3. 备份目录: `ssh -p 2222 user@nas "ls /vol2/1001/snapshots"`
4. 查看日志: `sudo journalctl -u btrbk-nas-backup.service -xe`

### 磁盘空间不足

```bash
# 查看快照占用
snap-du

# 清理旧快照
snap-cleanup

# 查看 btrfs 空间
sudo btrfs filesystem usage /
```

---

## 附录

### btrbk 保留策略格式

- `14d` = 保留 14 天
- `4w` = 保留 4 周
- `12m` = 保留 12 月
- `2y` = 保留 2 年
- `*y` = 保留所有年

示例：`"30d 12w 12m 2y"` 表示保留 30 天 + 12 周 + 12 月 + 2 年

### systemd timer 格式

- `hourly` = 每小时
- `daily` = 每天
- `weekly` = 每周
- `03:00` = 每天 03:00
- `Mon 03:00` = 每周一 03:00
