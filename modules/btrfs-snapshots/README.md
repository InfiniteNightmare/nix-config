# Btrfs 快照与备份模块

完整的 Btrfs 数据保护方案：本地快照 + NAS 远程备份

## 🎯 功能

- ✅ **本地快照** - 每小时自动快照，NixOS rebuild 时自动快照
- ✅ **NAS 备份** - 使用 btrbk 增量同步到 btrfs NAS
- ✅ **智能清理** - 自动清理旧快照和备份
- ✅ **便捷工具** - 测试、查看、管理命令

## 🚀 快速开始

### 1. 启用模块

```nix
# configuration.nix
{
  imports = [ ./modules/btrfs-snapshots ];

  # 本地快照
  services.btrfsSnapshots = {
    enable = true;
    snapshotOnRebuild = true;
    timeline.enable = true;
    configs = {
      root.subvolume = "/";
      home.subvolume = "/home";
      data.subvolume = "/data";
    };
  };

  # NAS 备份（可选但推荐）
  services.btrfsNasBackup = {
    enable = true;
    nasHost = "10.214.131.20";
    nasPort = 2222;
    nasUser = "charname";
    sshKeyFile = "/home/charname/.ssh/id_ed25519";
    backupBasePath = "/vol2/1001/snapshots";
  };
}
```

### 2. 应用配置

```bash
sudo nixos-rebuild switch
```

### 3. 验证

```bash
# 测试 NAS 连接
nas-backup-test

# 查看快照状态
snapshot-manager status

# 查看 NAS 备份状态
nas-backup-status

# 手动触发首次备份
nas-backup-manual
```

## 🛠️ 常用命令

### 本地快照

```bash
snap-ls              # 列出所有快照
snap-home            # 列出 home 分区快照
snap-status          # 查看快照状态
snapshot-manager create home "描述"  # 手动创建快照
```

### NAS 备份

```bash
nas-backup-test      # 测试 NAS 连接和配置
nas-backup-status    # 查看备份状态
nas-backup-manual    # 手动触发备份
```

### 服务管理

```bash
# 查看服务状态
sudo systemctl status snapper-timeline.timer
sudo systemctl status btrbk-nas-backup.timer

# 查看日志
sudo journalctl -u btrbk-nas-backup.service -f
```

## 📊 数据保护架构

```
层 1: 本地快照 (snapper)
  └─ 每小时自动，保留 24h/7d/4w/6m/2y
  └─ 用途：快速恢复误操作

层 2: NAS 备份 (btrbk)
  └─ 每天自动，保留 30d/12w/12m/2y
  └─ 用途：防止硬盘故障
```

## 🔧 配置选项

### services.btrfsSnapshots

| 选项 | 默认值 | 说明 |
|------|--------|------|
| `enable` | false | 启用本地快照 |
| `snapshotOnRebuild` | false | rebuild 时创建快照 |
| `snapshotOnBoot` | false | 启动时创建快照 |
| `timeline.enable` | false | 启用定时快照 |
| `timeline.limits.hourly` | 24 | 保留小时快照数量 |
| `timeline.limits.daily` | 7 | 保留每日快照数量 |
| `configs` | {} | subvolume 配置 |

### services.btrfsNasBackup

| 选项 | 默认值 | 说明 |
|------|--------|------|
| `enable` | false | 启用 NAS 备份 |
| `nasHost` | "10.214.131.20" | NAS 地址 |
| `nasPort` | 2222 | SSH 端口 |
| `nasUser` | "charname" | SSH 用户 |
| `sshKeyFile` | - | SSH 密钥路径 |
| `backupBasePath` | "/vol2/1001/snapshots" | NAS 备份路径 |
| `schedule` | "daily" | 备份频率 |
| `volumes` | {home,root,data} | 要备份的卷 |

## 📖 详细文档

- **[快速开始指南](docs/QUICKSTART.md)** - 详细的部署步骤
- **[配置参考](docs/CONFIGURATION.md)** - 完整的配置选项说明

## ⚠️ 重要说明

### 快照 ≠ 备份

- 快照在同一磁盘上，无法防止硬盘故障
- **强烈建议配置 NAS 备份**

### NixOS Generation vs Btrfs 快照

- 它们是**完全独立**的系统
- `nix.gc` 清理 NixOS generation（不影响快照）
- `snapper` 清理 Btrfs 快照（不影响 generation）

### 为什么使用 btrbk？

btrbk 专为 btrfs 设计：
- ⚡ 传输速度快（btrfs send/receive）
- 💾 空间效率高（增量传输）
- 🔄 保留快照结构（易于恢复）

如果 NAS 不支持 btrfs，可以改用 Restic（见文档）。

## 🧪 恢复示例

### 从本地快照恢复

```bash
# 查看快照
ls /home/.snapshots/

# 恢复单个文件
sudo cp /home/.snapshots/42/snapshot/user/file.txt ~/
```

### 从 NAS 恢复

```bash
# 在 NAS 上查看备份
ssh -p 2222 user@nas "ls /vol2/1001/snapshots/home/"

# btrbk 会自动处理增量恢复
```

## 🆘 故障排除

### 快照服务未启动

```bash
sudo systemctl start snapper-timeline.timer
sudo systemctl enable snapper-timeline.timer
```

### NAS 备份失败

```bash
# 运行测试
nas-backup-test

# 查看详细日志
sudo journalctl -u btrbk-nas-backup.service -xe
```

### 磁盘空间不足

```bash
# 查看空间
df -h
snap-du

# 清理旧快照
snap-cleanup
```

## 📝 文件结构

```
modules/btrfs-snapshots/
├── default.nix         # 本地快照模块
├── nas-backup.nix      # NAS 备份模块
├── README.md           # 本文档
└── docs/
    ├── QUICKSTART.md   # 详细部署指南
    └── CONFIGURATION.md # 配置参考手册
```

## 📄 许可证

MIT
