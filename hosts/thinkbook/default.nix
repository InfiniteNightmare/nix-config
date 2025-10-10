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
    ../../secrets
    inputs.agenix.nixosModules.default
  ];

  boot = {
    kernelPackages = pkgs.linuxPackages_zen;
    kernelParams = [ "amd_pstate=active" ];
    loader = {
      grub = {
        enable = true;
        device = "nodev";
        efiSupport = true;
        useOSProber = true;
      };
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
    };
  };

  windowsFonts = {
    enable = true;
    uuid = "868C96948C967E7D";
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
    httpProxy = "http://127.0.0.1:7897";
    httpsProxy = "http://127.0.0.1:7897";
    allProxy = "socks5://127.0.0.1:7897";
  };
  networking.firewall.allowedTCPPorts = [
    8384
    22000
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

  services.displayManager = {
    enable = true;
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

  services.blueman.enable = true;

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
      "https://mirrors.ustc.edu.cn/nix-channels/store"
      "https://cache.nixos.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = ''--delete-older-than 1w'';
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
    niri.enable = true;
    nix-ld = {
      enable = true;
      package = pkgs.nix-ld-rs;
    };
  };

  security.polkit.enable = true;
  services = {
    avahi.enable = true;
    geoclue2.enable = true;
    upower.enable = true;
  };

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

  system.stateVersion = "25.05";
}
