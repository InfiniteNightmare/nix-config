# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{
  inputs,
  pkgs,
  userName,
  lib,
  config,
  ...
}:

let
  # Use nixpkgs' niri so its glibc/mesa always match /run/opengl-driver.
  # niri-flake's cached binaries are built against its own (older) nixpkgs
  # pin; across a glibc bump niri then fails to dlopen the system GBM
  # drivers (GLIBC_x.y not found) and the session freezes with a black
  # console after greetd.
  niriPackage = pkgs.niri;
  # See flake.nix nixpkgs-aws-lc: pin clash-verge-rev past the aws-lc-sys breakage.
  clashPackage =
    let
      p = inputs.nixpkgs-aws-lc.legacyPackages.${pkgs.system}.clash-verge-rev;
    in
    if p.version == "2.5.2" then
      p
    else
      throw "clash-verge-rev pin drifted to ${p.version}; check if upstream added aws-lc to its expression, then re-pin or unpin (flake.nix nixpkgs-aws-lc)";
  proxySettings = import ../../lib/proxy-settings.nix;
in
{
  imports = [
    ./hardware-configuration.nix
    ./locale.nix
    inputs.agenix.nixosModules.default
    inputs.chaotic.nixosModules.default
  ];

  boot = {
    kernelPackages = pkgs.linuxPackages_cachyos-lto-znver4;
    resumeDevice = "/dev/disk/by-uuid/fac29ae7-61d6-4fd9-88cc-b5ab0c55517c";
    kernelParams = [
      "amd_pstate=active"
      "mem_sleep_default=deep"
      "hibernate_compression_threads=6"
      # TANCHJIM BUNNY (KTMicro) can't survive USB resume; reset it instead.
      "usbcore.quirks=31b2:1112:b"
    ];
    loader = {
      grub = {
        enable = true;
        device = "nodev";
        efiSupport = true;
        useOSProber = true;
        copyKernels = false;
        configurationLimit = 2;
      };
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
    };
    # CachyOS kernel defaults to 100; too swap-happy for a 16G SSD partition.
    kernel.sysctl."vm.swappiness" = 20;
  };

  # nixos-hardware 早期 KMS 会把 amdgpu.ko + 37MB 固件拖进 initrd;initrd 无 LUKS 用不上
  hardware.amdgpu.initrd.enable = false;

  # CachyOS LAVD scheduler via sched_ext; runtime-swappable via scxctl, falls back to EEVDF if it misbehaves.
  services.scx-loader = {
    enable = true;
    config.default_sched = "scx_lavd";
  };

  # tailnet 入口:校园网 DHCP IP 漂移,collie/手机接入都挂在 serve 上
  services.tailscale.enable = true;

  windowsFonts = {
    enable = true;
    uuid = "102ABC442ABC289C";
    mountPoint = "/var/lib/windows-ro";
    fsType = "ntfs";
    readonly = true;
    autoMount = true;
    autoMountIdleTimeout = "60s";
    allowFail = true;
  };

  networking = {
    hostName = "nixos";
    hosts."10.214.131.20" = [ "fnos-lan.charname.fnos.net" ];
    networkmanager.enable = true;
    proxy = proxySettings;
    firewall = {
      allowedTCPPorts = [
        22000
        53317
      ];
      allowedUDPPorts = [
        22000
        21027
        53317
      ];
    };
  };

  time.timeZone = "Asia/Shanghai";

  security = {
    rtkit.enable = true;
    polkit.enable = true;
  };

  systemd.services.micGainFix = {
    description = "Apply safe internal microphone gain";
    after = [ "sound.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      ${pkgs.alsa-utils}/bin/amixer -c 1 sset 'Internal Mic Boost' 0 || true
      ${pkgs.alsa-utils}/bin/amixer -c 1 sset Capture 35% || true
    '';
  };

  # FnLock on at boot so F1-F12 act as standard function keys. The firmware
  # powers on with the hotkey/media layer primary and only exposes the
  # preference through the ideapad_laptop `platform::fnlock` LED (1 = F-keys
  # primary); the think_lmi BIOS attributes that could persist it are not
  # writable without an admin password. Fn+Esc still works as a runtime
  # override.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="leds", KERNEL=="platform::fnlock", ATTR{brightness}="1"
  '';

  # Avahi can leave a stale PID file after rebuild restarts; remove it before
  # the service sandbox drops the privileges needed to clean /run/avahi-daemon.
  systemd.services.avahi-daemon.serviceConfig.ExecStartPre =
    "+${pkgs.coreutils}/bin/rm -f /run/avahi-daemon/pid";

  systemd.tmpfiles.rules = [
    # Keep the mounted data subvolume private to its owner.
    "d /data 0700 ${userName} users -"
    # Leave enough RAM for the kernel's hibernation snapshot workspace after
    # device drivers freeze; the default image target was too large under load.
    "w /sys/power/image_size - - - - 6442450944"
    # Name the stuck device callback in the journal when hibernate aborts.
    "w /sys/power/pm_debug_messages - - - - 1"
  ];

  # Firmware moves one ACPI data block per cold boot, so a hibernated image
  # can never pass the resume CRC; the session button powers off instead.
  systemd.sleep.settings.Sleep.HibernateMode = "shutdown";

  # services.blueman.enable = true;

  users.users.${userName} = {
    isNormalUser = true;
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
    shell = pkgs.fish;
  };

  nixpkgs.config.allowUnfree = true;

  # This host is managed exclusively through the flake lock file.
  nix.channel.enable = false;

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    # Keep store deduplication off the interactive rebuild critical path; the
    # scheduled optimiser below performs the same work in the background.
    auto-optimise-store = false;
    builders-use-substitutes = true;
    substituters = [
      "https://cache.numtide.com"
      "https://noctalia.cachix.org"
      "https://niri.cachix.org"
      "https://mirrors.ustc.edu.cn/nix-channels/store"
      "https://cache.nixos.org"
    ];
    trusted-public-keys = [
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
      "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
  };

  nix.gc = {
    automatic = true;
    dates = "monthly";
    # System generations and their checkpoints are retired together by nixos-boot-clean.
    options = "";
  };

  nix.optimise = {
    automatic = true;
    dates = [ "weekly" ];
  };

  environment = {
    systemPackages = with pkgs; [
      vim
      git
      wget
      curl
      age
      ragenix
      nodejs
    ];
    variables = {
      EDITOR = "nvim";
      QT_IM_MODULE = "fcitx";
      XMODIFIERS = "@im=fcitx";
      SDL_IM_MODULE = "fcitx";
      INPUT_METHOD = "fcitx";
      GLFW_IM_MODULE = "ibus";
    };
    shells = [ pkgs.fish ];
    sessionVariables.NIXOS_OZONE_WL = "1";
  };

  programs = {
    fish.enable = true;
    nixosCleanSwitch = {
      enable = true;
      flake = "/home/${userName}/nix-config";
      host = "thinkbook";
      generationSnapshots.enable = true;
    };
    clash-verge = {
      enable = true;
      autoStart = true;
      package = clashPackage;
      # serviceMode = true;
      # tunMode = true;
      # group = "users";
    };
    niri = {
      enable = true;
      package = niriPackage;
    };
    nix-ld.enable = true;
    steam = {
      enable = true;
      remotePlay.openFirewall = false;
    };
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  services = {
    # Keep ZCode from silently packing workspaces (full .git history
    # included) for upload; see modules/nixos/zcode-snapshot-lock.nix.
    zcode-snapshot-lock.enable = true;
    xserver.xkb = {
      layout = "us";
      variant = "";
    };
    greetd = {
      enable = true;
      useTextGreeter = true;
      settings = {
        # Start the normal user session once at boot. Keeping the desktop in
        # default_session makes logind classify it as a greeter session.
        initial_session = {
          command = "${niriPackage}/bin/niri-session";
          user = userName;
        };
        default_session = {
          command = "${pkgs.greetd}/bin/agreety --cmd ${niriPackage}/bin/niri-session";
          user = "greeter";
        };
      };
    };
    pipewire = {
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
    upower.enable = true;
    # power-profiles-daemon.enable = true;
    udisks2 = {
      enable = true;
      mountOnMedia = true;
    };
    printing = {
      enable = true;
      # The existing printer queue remains available without a permanent
      # remote-printer discovery daemon.
      browsed.enable = false;
      drivers = with pkgs; [
        gutenprint
        hplipWithPlugin
      ];
    };
    avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };
    # TLP 电源管理配置
    tlp = {
      enable = true;
      settings = {
        # The current kernel ignores the deprecated vm.laptop_mode setting;
        # clear TLP's inherited defaults to avoid the ineffective writes.
        DISK_IDLE_SECS_ON_AC = "";
        DISK_IDLE_SECS_ON_BAT = "";

        # CPU 性能调度
        CPU_SCALING_GOVERNOR_ON_AC = "performance";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

        # EPP/平台 profile stay off the max: racing to top frequency for every
        # blip costs heat and fan wear for imperceptible desktop gains.
        CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
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
        PLATFORM_PROFILE_ON_AC = "balanced";
        PLATFORM_PROFILE_ON_BAT = "low-power";

        # 运行时电源管理
        RUNTIME_PM_ON_AC = "on";
        RUNTIME_PM_ON_BAT = "auto";

        # USB 自动挂起
        USB_AUTOSUSPEND = 1;

        # 无线设备电源管理
        WIFI_PWR_ON_AC = "off";
        WIFI_PWR_ON_BAT = "on";

        # ThinkBooks expose a fixed Long_Life charging mode. Let TLP apply it
        # after its other startup settings instead of writing the deprecated
        # conservation_mode sysfs attribute from an early udev rule.
        START_CHARGE_THRESH_BAT0 = 0;
        STOP_CHARGE_THRESH_BAT0 = 1;
        RESTORE_THRESHOLDS_ON_BAT = 1;
      };
    };
  };
  powerManagement.enable = true;

  filesystems.webdav = {
    enable = true;
    identityPaths = [ "/home/${userName}/.ssh/id_ed25519" ];
    mounts = {
      # Reverted from SFTP: the evening 2.4GHz link (co-channel APs, RTT
      # spikes 100-400ms, lossy) wedges SFTP's single multiplexed channel
      # into queue storms and dead mounts. WebDAV's per-request pooled
      # HTTP conns self-heal and are the proven-stable shape on this link.
      # The module keeps the sftp backend for when the link is fixed.
      fnos = {
        url = "https://fnos-lan.charname.fnos.net:5006";
        username = userName;
        encryptedPasswordFile = ../../secrets/webdav-password.age;
        mountPoint = "/mnt/fnos";
        readOnly = false;
        cache.sizeMiB = 5000;
        automount = true;
      };
    };
  };

  xdg.portal = {
    enable = true;
    # xdgOpenUsePortal = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-termfilechooser
      xdg-desktop-portal-gtk
    ];
    # Keep Niri's upstream routing for screencast and desktop integration,
    # while using the terminal chooser only for the FileChooser interface.
    config.niri = {
      default = [
        "gnome"
        "gtk"
      ];
      "org.freedesktop.impl.portal.Access" = "gtk";
      "org.freedesktop.impl.portal.FileChooser" = "termfilechooser";
      "org.freedesktop.impl.portal.Notification" = "gtk";
      "org.freedesktop.impl.portal.Secret" = "gnome-keyring";
    };
  };

  system.stateVersion = "25.05";
}
