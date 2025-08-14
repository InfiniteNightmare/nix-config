# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./locale.nix
  ];

  # Bootloader.
  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 10;
  };
  boot.loader.efi.canTouchEfiVariables = true;
  boot.supportedFilesystems = [ "ntfs" ];

  networking.hostName = "OptiPlex7000"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Asia/Shanghai";

  # Configure keymap in X11
  services.xserver = {
    xkb = {
      layout = "us";
      variant = "";
    };
  };

  services.displayManager = {
    enable = true;
    # sddm = {
    # enable = true;
    # wayland.enable = true;
    # autoNumlock = true;
    # theme = "sddm-astronaut-theme";
    # package = pkgs.kdePackages.sddm;
    # extraPackages = [ pkgs.kdePackages.qt5compat ];
    # settings = {
    # Theme = {
    # Current = "sddm-astronaut-theme";
    # };
    # };
    # };
  };

  # rtkit is optional but recommended
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
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

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.shb = {
    isNormalUser = true;
    description = "Haobo Sun";
    extraGroups = [
      "networkmanager"
      "docker"
      "davfs2"
      "wheel"
    ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICaNeGrkIkv2ImATJx9e+xL2ExOklh62megNL3rbE3CD 742851870@qq.com"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF0+hnYZo4aaoqLCtG+nW/bBhEPfzrlynRDG7mHmJpAw Termux"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICAzO9XqJYAdnnuZcvtRLndOqFaFqtSybNKEhKh1sNZC haobosunzju@outlook.com"
    ];
    packages = with pkgs; [ ];
    shell = pkgs.nushell;
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # # Wayland fcitx5 support
  nixpkgs.config = {
    microsoft-edge.commandLineArgs = "--enable-wayland-ime";
    vscode.commandLineArgs = "--enable-wayland-ime";
  };

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    # auto-optimise-store = true;
    builders-use-substitutes = true;
    substituters = [
      "https://mirrors.ustc.edu.cn/nix-channels/store"
      "https://anyrun.cachix.org"
      "https://hyprland.cachix.org"
      # "https://walker.cachix.org"
    ];
    trusted-public-keys = [
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      "anyrun.cachix.org-1:pqBobmOjI7nKlsUMV25u9QHa9btJK65/C8vnO3p346s="
      # "walker.cachix.org-1:fG8q+uAaMqhsMxWjwvk0IMb4mFPFLqHjuvfwQxE4oJM="
    ];
  };

  nix.settings.auto-optimise-store = true;

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = ''--delete-older-than 1w'';
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    git
    wget
    curl
    helix
    sddm-astronaut
    clash-verge-rev
  ];

  environment.variables = {
    EDITOR = "hx";
    # GTK_IM_MODULE = "fcitx";
    QT_IM_MODULE = "fcitx";
    XMODIFIERS = "@im=fcitx";
    SDL_IM_MODULE = "fcitx";
    INPUT_METHOD = "fcitx";
    GLFW_IM_MODULE = "ibus";
  };

  environment.shells = [ pkgs.nushell ];

  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  programs = {
    hyprland.enable = true;
    niri.enable = true;
    xwayland.enable = true;
    nix-ld = {
      enable = true;
      package = pkgs.nix-ld-rs;
    };
  };

  programs.ssh.hostKeyAlgorithms = [
    "ssh-ed25519"
    "ssh-rsa"
  ];

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    ports = [ 2222 ];
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
    openFirewall = true;
  };

  virtualisation = {
    docker = {
      enable = true;
      # storageDriver = "btrfs";
      autoPrune.enable = true;
      daemon.settings = {
        data-root = "/home/shb/docker-data";
        fixed-cidr-v6 = "fd00::/80";
        ipv6 = true;
        "registry-mirrors" = [
          "https://docker.1panel.dev"
        ];
        http-proxy = "http://127.0.0.1:7897";
        https-proxy = "http://127.0.0.1:7897";
      };
    };
    # vmware.host.enable = true;
  };

  services = {
    udisks2.enable = true;
    cpupower-gui.enable = true;
    upower.enable = true;
    fail2ban.enable = true;
    davfs2 = {
      enable = true;
      settings = {
        globalSection = {
          use_locks = false;
        };
      };
    };
    # rustdesk-server = {
    #   enable = true;
    #   openFirewall = true;
    #   relayIP = "10.214.131.20";
    #   extraSignalArgs = [
    #     "-k"
    #     "_"
    #   ];
    #   extraRelayArgs = [
    #     "-k"
    #     "_"
    #   ];
    # };
  };

  security.polkit.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Did you read the comment?
}
