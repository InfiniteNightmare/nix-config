{ pkgs, inputs, ... }:
let
  wechatDirect = pkgs.callPackage (pkgs.path + "/pkgs/by-name/we/wechat/linux.nix") {
    pname = "wechat";
    version = "4.1.0.13";
    src = pkgs.fetchurl {
      url = "https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_x86_64.AppImage";
      hash = "sha256-+r5Ebu40GVGG2m2lmCFQ/JkiDsN/u7XEtnLrB98602w=";
    };
    meta = pkgs.wechat.meta;
  };
in
{
  imports = [
    ./editor
    ./fcitx5
    ./shell
    ./niri
    ./noctalia
  ];

  home.username = "charname";
  home.homeDirectory = "/home/charname";

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

    btop # replacement of htop
    iotop # io monitoring
    iftop # network monitoring

    # system call monitoring
    strace # system call monitoring
    # ltrace # library call monitoring
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
    # (microsoft-edge.override { commandLineArgs = [ "--enable-wayland-ime" ]; })

    zotero

    obsidian

    # program
    devcontainer

    # clipboard
    wl-clipboard
    cliphist

    # swaynotificationcenter

    keepassxc

    # polkit-kde-agent
    mate.mate-polkit
    gnome-keyring

    xdg-utils

    motrix

    pandoc

    gimp

    grim

    slurp

    snipaste

    fluent-reader

    zed-editor
    vscode
    uv
    nodejs

    devbox

    neovide

    nemo-with-extensions

    # bilibili

    pwvucontrol
    helvum

    splayer

    # sddm-astronaut

    xcur2png

    # waynnvnc
    # wlvncc

    localsend
    freerdp
    # deskflow

    waveterm

    czkawka

    # follow

    gtypist
    ttyper

    # osu-lazer
    # taisei

    nil
    nixd

    xwayland-satellite

    wpsoffice-cn

    wechatDirect
    wemeet

    kazumi

    cherry-studio
  ];

  programs.git = {
    enable = true;
    settings = {
      user.name = "InfiniteNightmare";
      user.email = "742851870@qq.com";
    };
  };

  programs.obs-studio = {
    enable = true;
    plugins = with pkgs.obs-studio-plugins; [
      wlrobs
      obs-pipewire-audio-capture
    ];
  };

  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    enableNushellIntegration = true;
    nix-direnv.enable = true;
  };

  programs.zen-browser = {
    enable = true;
    policies = {
      DisableAppUpdate = true;
      DisableTelemetry = true;
    };
    nativeMessagingHosts = [ pkgs.firefoxpwa ];
    # Add any other native connectors here
  };

  services.syncthing = {
    enable = true;
  };

  xdg = {
    enable = true;
  };

  stylix = {
    # Managed in Home Manager only. Do not configure Stylix in NixOS modules to avoid mismatch.
    enable = true;
    base16Scheme = "${inputs.stylix.inputs.tinted-schemes}/base16/catppuccin-mocha.yaml";
    polarity = "dark";

    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.fira-code;
        name = "FiraCode Nerd Font Mono";
      };
      sansSerif = {
        package = pkgs.noto-fonts;
        name = "Noto Sans";
      };
      serif = {
        package = pkgs.noto-fonts;
        name = "Noto Serif";
      };
      emoji = {
        package = pkgs.noto-fonts-color-emoji;
        name = "Noto Color Emoji";
      };
    };

    targets.zen-browser.profileNames = [ "default" ];
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
