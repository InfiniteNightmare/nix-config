# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{
  lib,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./locale.nix
    ../../modules/windows-fonts.nix
    ../../modules/filesystems/webdav.nix
    ../../modules/container
    ../../modules/btrfs-snapshots
    ../../secrets
    inputs.agenix.nixosModules.default
  ];

  boot = {
    kernelPackages = pkgs.linuxPackages_zen;
    kernelParams = [
      "amd_pstate=active"
      "mem_sleep_default=deep"
    ];
    loader = {
      grub = {
        enable = true;
        device = "nodev";
        efiSupport = true;
        useOSProber = true;
        copyKernels = false;
        configurationLimit = 3;
      };
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
    };
  };

  windowsFonts = {
    enable = true;
    uuid = "102ABC442ABC289C";
    mountPoint = "/var/lib/windows-ro";
    fsType = "ntfs3";
    readonly = true;
    autoMount = true;
    autoMountIdleTimeout = "60s";
    allowFail = true;
    autoFallback = true;
    # Bind mount removed; fontconfig should include: /var/lib/windows-ro/Windows/Fonts
    refreshFontCacheOnActivation = true;
  };

  networking.hostName = "nixos";

  networking.networkmanager.enable = true;
  networking.proxy = {
    httpProxy = "http://127.0.0.1:7890";
    httpsProxy = "http://127.0.0.1:7890";
    allProxy = "socks5://127.0.0.1:7890";
  };
  networking.firewall.allowedTCPPorts = [
    3025
    8384
    22000
    53317
  ];
  networking.firewall.allowedUDPPorts = [
    22000
    21027
  ];

  time.timeZone = "Asia/Shanghai";

  services.xserver = {
    xkb = {
      layout = "us";
      variant = "";
    };
  };

  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.niri-unstable}/bin/niri-session";
        user = "charname";
      };
    };
  };

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;

    wireplumber.extraConfig.bluetoothEnhancements = {
      "monitor.bluez.properties" = {
        "bluez5.enable-sbc-xq" = true;
        "bluez5.enable-msbc" = true;
        "bluez5.enable-hw-volume" = true;
        "bluez5.roles" = [
          "hsp_hs"
          "hsp_ag"
          "hfp_hf"
          "hfp_ag"
        ];
      };
    };
  };

  # services.blueman.enable = true;

  programs.fish.enable = true;

  users.users.charname = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "davfs2"
    ];
    shell = pkgs.fish;
  };

  nixpkgs.config.allowUnfree = true;

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
    builders-use-substitutes = true;
    substituters = [
      "https://niri.cachix.org"
      "https://mirrors.ustc.edu.cn/nix-channels/store"
      "https://cache.nixos.org"
    ];
    trusted-public-keys = [
      "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 1w";
  };

  environment.systemPackages = with pkgs; [
    vim
    git
    wget
    curl
    helix
    sddm-astronaut
    clash-verge-rev
    age
    ragenix
    system-config-printer
  ];

  environment.variables = {
    EDITOR = "hx";
    QT_IM_MODULE = "fcitx";
    XMODIFIERS = "@im=fcitx";
    SDL_IM_MODULE = "fcitx";
    INPUT_METHOD = "fcitx";
    GLFW_IM_MODULE = "ibus";
  };

  environment.shells = [ pkgs.fish ];
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  programs = {
    niri = {
      enable = true;
      package = pkgs.niri-unstable;
    };
    nix-ld.enable = true;
    steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
    };
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  security.polkit.enable = true;
  services = {
    geoclue2.enable = true;
    upower.enable = true;
    noctalia-shell.enable = true;
    # power-profiles-daemon.enable = true;
    udisks2 = {
      enable = true;
      mountOnMedia = true;
    };
    printing = {
      enable = true;
      drivers = with pkgs; [
        gutenprint
        hplip
        hplipWithPlugin
      ];
    };
    avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };
    udev.extraRules = ''
      SUBSYSTEM=="platform", KERNEL=="VPC2004:*", DRIVER=="ideapad_acpi", ACTION=="add", ATTR{conservation_mode}="1"
      SUBSYSTEM=="platform", KERNEL=="VPC2004:*", DRIVER=="ideapad_acpi", ACTION=="change", ATTR{conservation_mode}="1"
    '';

    # TLP 电源管理配置
    tlp = {
      enable = true;
      settings = {
        # CPU 性能调度
        CPU_SCALING_GOVERNOR_ON_AC = "performance";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

        # AMD CPU 能耗模式
        CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
        CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

        # CPU 频率范围
        CPU_MIN_PERF_ON_AC = 0;
        CPU_MAX_PERF_ON_AC = 100;
        CPU_MIN_PERF_ON_BAT = 0;
        CPU_MAX_PERF_ON_BAT = 30;

        # 启用 CPU Boost
        CPU_BOOST_ON_AC = 1;
        CPU_BOOST_ON_BAT = 0;

        # 平台配置文件
        PLATFORM_PROFILE_ON_AC = "performance";
        PLATFORM_PROFILE_ON_BAT = "low-power";

        # 运行时电源管理
        RUNTIME_PM_ON_AC = "on";
        RUNTIME_PM_ON_BAT = "auto";

        # USB 自动挂起
        USB_AUTOSUSPEND = 1;

        # 无线设备电源管理
        WIFI_PWR_ON_AC = "off";
        WIFI_PWR_ON_BAT = "on";

        # 电池保养：已启用 conservation_mode，不使用 TLP 充电阈值以避免冲突
        # START_CHARGE_THRESH_BAT0 = 40;
        # STOP_CHARGE_THRESH_BAT0 = 80;
      };
    };
  };
  powerManagement.enable = true;

  filesystems.webdav = {
    enable = true;
    mounts = {
      fnos = {
        url = "http://10.214.131.20:5005";
        username = "charname";
        secret = "webdav-password";
        mountPoint = "/mnt/fnos";
        readOnly = false;
        cache.sizeMiB = 100;
        automount = true;
      };
    };
  };

  xdg.portal = {
    enable = true;
    # xdgOpenUsePortal = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-wlr
      xdg-desktop-portal-gtk
    ];
    config.common.default = [
      "wlr"
      "gtk"
    ];
  };

  # ============================================
  # Btrfs 自动快照配置
  # ============================================
  services.btrfsSnapshots = {
    enable = true;

    # 在 NixOS rebuild 时创建快照（配置切换前）
    snapshotOnRebuild = true;

    # 在系统启动时创建快照
    snapshotOnBoot = true;

    # 定时快照配置
    timeline = {
      enable = true;
      limits = {
        hourly = 24; # 保留 24 小时的快照
        daily = 7; # 保留 7 天的每日快照
        weekly = 4; # 保留 4 周的每周快照
        monthly = 6; # 保留 6 个月的每月快照
        yearly = 2; # 保留 2 年的每年快照
      };
    };

    # 配置要快照的 subvolume
    configs = {
      # 根分区快照 - 保护系统文件和配置
      root = {
        subvolume = "/";
      };

      # Home 分区快照 - 保护用户数据（最重要）
      home = {
        subvolume = "/home";
      };

      # Data 分区快照 - 保护额外数据
      data = {
        subvolume = "/data";
      };

      # 注意：/nix 不需要快照，因为可以通过 NixOS 配置重建
      # /boot 也不需要，因为它不是 btrfs 文件系统
    };
  };

  # ============================================
  # NAS 备份配置（btrbk 增量同步到 btrfs NAS）
  # ============================================
  services.btrfsNasBackup = {
    enable = true;

    # NAS 配置
    nasHost = "10.214.131.20";
    nasPort = 2222;
    nasUser = "charname";
    sshKeyFile = "/home/charname/.ssh/id_ed25519";
    backupBasePath = "/vol2/1001/snapshots";

    # 备份计划
    schedule = "daily"; # 每天备份

    # 要备份的 volume（使用默认配置：home, root, data）
    # volumes 已经有默认值，无需重复配置

    # 保留策略
    retention = {
      snapshot = "14d 4w"; # 本地快照：14天 + 4周
      target = "30d 12w 12m 2y"; # NAS 备份：30天 + 12周 + 12月 + 2年
    };
  };

  specialisation = {
  };

  system.stateVersion = "25.05";
}
