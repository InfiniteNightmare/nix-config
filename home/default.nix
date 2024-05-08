{ config, pkgs, ... }:
{
  imports = [
    # ./eww
    ./program
    ./fcitx5
    ./hyprland
    ./waybar
    ./shell
  ];

  home.username = "shb";
  home.homeDirectory = "/home/shb";

  # Wayland fcitx5 support
  nixpkgs.config = {
    microsoft-edge.commandLineArgs = "--enable-wayland-ime";
    vscode.commandLineArgs = "--enable-wayland-ime";
  };

  home.packages = with pkgs; [
    fastfetch
    joshuto # terminal file manager

    # archives
    zip
    xz
    unzip
    p7zip

    # utils
    ripgrep # recursively searches directories for a regex pattern
    jq # A lightweight and flexible command-line JSON processor
    yq-go # yaml processor https://github.com/mikefarah/yq
    eza # A modern replacement for ‘ls’
    fzf # A command-line fuzzy finder

    # networking tools
    mtr # A network diagnostic tool
    iperf3
    dnsutils # `dig` + `nslookup`
    ldns # replacement of `dig`, it provide the command `drill`
    aria2 # A lightweight multi-protocol & multi-source command-line download utility
    socat # replacement of openbsd-netcat
    nmap # A utility for network discovery and security auditing
    ipcalc # it is a calculator for the IPv4/v6 addresses

    # misc
    cowsay
    file
    which
    tree
    gnused
    gnutar
    gawk
    zstd
    gnupg

    # nix related
    #
    # it provides the command `nom` works just like `nix`
    # with more details log output
    nix-output-monitor

    # productivity
    hugo # static site generator
    glow # markdown previewer in terminal

    zenith # replacement of htop
    iotop # io monitoring
    iftop # network monitoring

    # system call monitoring
    strace # system call monitoring
    ltrace # library call monitoring
    lsof # list open files

    # system tools
    sysstat
    lm_sensors # for `sensors` command
    ethtool
    pciutils # lspci
    usbutils # lsusb
    hdparm

    # disk tools
    smartmontools
    nvme-cli
    parted

    udiskie

    sshpass

    # browser
    (microsoft-edge.override { commandLineArgs = [ "--enable-wayland-ime" ]; })

    zotero

    obsidian

    # program
    jetbrains-toolbox
    lapce
    zed-editor

    # clipboard
    wl-clipboard
    cliphist

    eww

    dunst

    keepassxc

    onedrivegui

    warp-terminal

    polkit-kde-agent

    xdg-utils

    wineWowPackages.waylandFull

    winetricks

    motrix

    (wpsoffice.override { useChineseVersion = true; })

    gimp
  ];

  programs.git = {
    enable = true;
    userName = "InfiniteNightmare";
    userEmail = "742851870@qq.com";
  };

  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = [ "hyprland" ];
    # configPackages = [ pkgs.xdg-desktop-portal-gtk ];
  };

  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    enableNushellIntegration = true;
    nix-direnv.enable = true;
  };

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "23.11";

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
