# 快速开始指南

## 📋 前提条件

- NixOS 系统
- Btrfs 文件系统
- （可选）btrfs NAS 用于远程备份

## 🚀 部署步骤

### 步骤 1: 配置模块

编辑主机配置文件（例如 `hosts/thinkbook/default.nix`）：

```nix
{
  imports = [ ../../modules/btrfs-snapshots ];

  # 本地快照
  services.btrfsSnapshots = {
    enable = true;
    snapshotOnRebuild = true;  # NixOS rebuild 时自动快照
    timeline.enable = true;     # 启用定时快照
    
    configs = {
      root.subvolume = "/";
      home.subvolume = "/home";
      data.subvolume = "/data";
    };
  };

  # NAS 备份（可选）
  services.btrfsNasBackup = {
    enable = true;
    nasHost = "10.214.131.20";
    nasPort = 2222;
    nasUser = "charname";
    sshKeyFile = "/home/charname/.ssh/id_ed25519";
    backupBasePath = "/vol2/1001/snapshots";
    schedule = "daily";
  };
}
```

### 步骤 2: 应用配置

```bash
cd ~/nix-config
sudo nixos-rebuild switch --flake .#thinkbook
```

### 步骤 3: 验证本地快照

```bash
# 查看服务状态
sudo systemctl status snapper-timeline.timer

# 创建测试快照
sudo snapshot-manager create home "初始快照"

# 查看快照列表
snap-home
```

### 步骤 4: 验证 NAS 备份（如果启用）

```bash
# 测试 NAS 连接
nas-backup-test

# 手动触发首次备份
nas-backup-manual

# 查看备份状态
nas-backup-status
```

## ✅ 验证清单

- [ ] snapper 定时器正在运行
- [ ] 可以创建和查看快照
- [ ] NAS 连接测试通过（如果启用）
- [ ] 首次 NAS 备份成功（如果启用）

## 🛠️ 常用命令速查

### 本地快照

```bash
snap-ls                              # 列出所有快照
snap-home                            # 列出 home 快照
snap-status                          # 查看状态
snapshot-manager create home "描述"  # 创建快照
```

### NAS 备份

```bash
nas-backup-test      # 测试连接
nas-backup-status    # 查看状态
nas-backup-manual    # 手动备份
```

## 📊 默认保留策略

### 本地快照
- 小时快照: 24 个（1 天）
- 每日快照: 7 个（1 周）
- 每周快照: 4 个（1 月）
- 每月快照: 6 个（半年）
- 每年快照: 2 个（2 年）

### NAS 备份
- 每日备份: 保留 30 天
- 每周备份: 保留 12 周
- 每月备份: 保留 12 月
- 每年备份: 保留 2 年

## 🧪 恢复测试

### 测试本地快照恢复

```bash
# 1. 创建测试文件
echo "test" > ~/test-file.txt

# 2. 创建快照
sudo snapshot-manager create home "恢复测试"

# 3. 删除文件
rm ~/test-file.txt

# 4. 查看快照
ls /home/.snapshots/*/snapshot/$(whoami)/

# 5. 恢复文件
sudo cp /home/.snapshots/*/snapshot/$(whoami)/test-file.txt ~/
```

### 测试 NAS 备份

```bash
# 查看 NAS 上的备份
ssh -p 2222 charname@10.214.131.20 "ls /vol2/1001/snapshots/"

# 查看备份状态
nas-backup-status
```

## ⚠️ 注意事项

1. **快照不是备份** - 快照在同一磁盘上，无法防止硬盘故障
2. **NAS 备份强烈推荐** - 提供真正的数据保护
3. **定期测试恢复** - 确保快照和备份可用
4. **监控磁盘空间** - 快照会占用额外空间

## 🆘 故障排除

### 快照服务未启动

```bash
sudo systemctl start snapper-timeline.timer
sudo systemctl enable snapper-timeline.timer
```

### NAS 连接失败

```bash
# 测试 SSH
ssh -p 2222 charname@10.214.131.20

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

## 📖 更多信息

- [配置参考](CONFIGURATION.md) - 完整的配置选项
- [主 README](../README.md) - 模块概述

---

**提示**: 本指南假设您已经配置好 SSH 密钥和 NAS 访问权限。