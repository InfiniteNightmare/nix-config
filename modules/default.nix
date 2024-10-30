{ config, pkgs, ... }:
{
  imports = [
    # ./eww
    ./anyrun
    ./editor
    ./fcitx5
    ./hyprland
    ./shell
  ];

  home.username = "shb";
  home.homeDirectory = "/home/shb";

  home.packages = with pkgs; [
    fastfetch

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
    traceroute

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
    cpu-x
    dmidecode

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

    # clipboard
    wl-clipboard
    cliphist

    eww

    swaynotificationcenter

    keepassxc

    onedrive
    onedrivegui

    polkit-kde-agent

    xdg-utils

    (wine.override {
      wineRelease = "wayland";
      wineBuild = "wineWow";
      openglSupport = true;
      vulkanSupport = true;
      waylandSupport = true;
    })

    bottles-unwrapped

    motrix

    pandoc

    gimp

    grim

    slurp

    snipaste

    fluent-reader

    zed-editor

    devbox

    neovide

    # (pkgs.appimageTools.wrapType2 {
    # name = "kando";
    # src = pkgs.fetchurl {
    # url = "https://github.com/kando-menu/kando/releases/download/v1.3.0/Kando-1.3.0-x86_64.AppImage";
    # sha256 = "1a5h0yr6myi98l1js39hd8ndysm1wr07b3m0h8wwdbd5lnnyz3ip";
    # };
    # })

    # bilibili

    pwvucontrol

    netease-cloud-music-gtk

    # sddm-astronaut
    dracula-icon-theme

    hyprcursor
    xcur2png

    xpipe

    syncthingtray

    wayvnc
    wlvncc

    rustdesk
    # rustdesk-server
    # pm2
    lan-mouse
    localsend

    xplorer

    czkawka

    follow

    gtypist
    ttyper

    hyprpanel

    ags
  ];

  programs.git = {
    enable = true;
    userName = "InfiniteNightmare";
    userEmail = "742851870@qq.com";
  };

  programs.obs-studio = {
    enable = true;
    plugins = with pkgs.obs-studio-plugins; [ wlrobs ];
  };

  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    enableNushellIntegration = true;
    nix-direnv.enable = true;
  };

  services.syncthing = {
    enable = true;
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
