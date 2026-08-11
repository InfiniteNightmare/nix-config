# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{
  inputs,
  pkgs,
  userName,
  ...
}:

let
  niriPackage = inputs.niri.packages.${pkgs.stdenv.hostPlatform.system}.niri-unstable;
  proxySettings = import ../../lib/proxy-settings.nix;
in
{
  imports = [
    ./hardware-configuration.nix
    ./locale.nix
    ../../modules/nixos/windows-fonts.nix
    ../../modules/nixos/boot-cleanup.nix
    ../../modules/nixos/webdav.nix
    ../../modules/nixos/containers.nix
    ../../modules/nixos/zju-connect.nix
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
    fsType = "ntfs";
    readonly = true;
    autoMount = true;
    autoMountIdleTimeout = "60s";
    allowFail = true;
  };

  networking = {
    hostName = "nixos";
    networkmanager = {
      enable = true;
      ensureProfiles.profiles.wired-10-214-104 = {
        connection = {
          id = "wired-10-214-104";
          type = "ethernet";
          interface-name = "enp2s0";
          autoconnect = true;
          autoconnect-priority = 100;
        };
        ipv4 = {
          method = "manual";
          addresses = "10.214.104.3/24";
          gateway = "10.214.104.1";
          dns = "10.10.0.21";
          dns-priority = -50;
          route-metric = 100;
          never-default = false;
        };
        ipv6.method = "disabled";
      };
    };
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

  # Avahi can leave a stale PID file after rebuild restarts; remove it before
  # the service sandbox drops the privileges needed to clean /run/avahi-daemon.
  systemd.services.avahi-daemon.serviceConfig.ExecStartPre =
    "+${pkgs.coreutils}/bin/rm -f /run/avahi-daemon/pid";

  # services.blueman.enable = true;

  users.users.${userName} = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
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
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  environment = {
    systemPackages = with pkgs; [
      vim
      git
      wget
      curl
      helix
      age
      ragenix
      system-config-printer
      nodejs
    ];
    variables = {
      EDITOR = "hx";
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
    };
    clash-verge = {
      enable = true;
      autoStart = true;
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
      remotePlay.openFirewall = true;
    };
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  services = {
    zjuConnect = {
      installCli = true;

      # Enable after adding an agenix secret for the account password.
      # enable = true;
      # username = "your-zju-account";
      # passwordSecret = "zju-connect-password";
      # protocol = "easyconnect";
      # socksBind = "127.0.0.1:1080";
      # httpBind = "127.0.0.1:1081";

      # For aTrust, persist client state to avoid repeated verification.
      # protocol = "atrust";
      # clientDataFile = "/var/lib/zju-connect/client_data.json";
    };
    xserver.xkb = {
      layout = "us";
      variant = "";
    };
    greetd = {
      enable = true;
      settings.default_session = {
        command = "${niriPackage}/bin/niri-session";
        user = userName;
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
    geoclue2.enable = true;
    upower.enable = true;
    # power-profiles-daemon.enable = true;
    udisks2 = {
      enable = true;
      mountOnMedia = true;
    };
    printing = {
      enable = true;
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
    identityPaths = [ "/home/${userName}/.ssh/id_ed25519" ];
    mounts = {
      fnos = {
        url = "http://10.214.131.20:5005";
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
      xdg-desktop-portal-wlr
      xdg-desktop-portal-gtk
    ];
    config.common.default = [
      "termfilechooser"
      "wlr"
      "gtk"
    ];
  };

  system.stateVersion = "25.05";
}
