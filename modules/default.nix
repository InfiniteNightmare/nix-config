{
  inputs,
  pkgs,
  userName,
  ...
}:
let
  # Wrap Zotero to force X11 backend via XWayland for niri compatibility
  zoteroX11 = pkgs.symlinkJoin {
    name = "zotero-x11";
    paths = [ pkgs.zotero ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/zotero \
        --set GDK_BACKEND x11 \
        --set MOZ_ENABLE_WAYLAND 0
    '';
  };
in
{
  imports = [
    ./language-tools
    ./editor
    ./fcitx5
    ./llm-agents
    ./proxy
    ./shell
    ./niri
    ./xdg
    ./media
    ./latex
  ];

  home.username = userName;
  home.homeDirectory = "/home/${userName}";

  home.packages = with pkgs; [
    fastfetch

    gnumake

    # archives
    zip
    xz
    unzip
    p7zip
    pigz
    unrar

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

    # browser
    # (microsoft-edge.override { commandLineArgs = [ "--enable-wayland-ime" ]; })

    zoteroX11

    obsidian

    # program
    gh
    # devcontainer

    # clipboard
    wl-clipboard

    # swaynotificationcenter

    keepassxc

    # polkit-kde-agent
    gnome-keyring

    xdg-utils

    motrix

    pandoc

    # gimp

    grim
    slurp
    hyprpicker

    snipaste

    fluent-reader

    vscode
    uv

    devbox

    neovide

    # bilibili

    pwvucontrol
    crosspipe

    mpvpaper
    splayer

    xcur2png

    localsend
    freerdp
    remmina
    rustdesk
    # deskflow

    waveterm
    warp-terminal

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
    drawio

    qq
    wechat
    wemeet

    # animeko

    feishu

    taisei

    brave
    readest

    obs-studio
  ];

  programs.git = {
    enable = true;
    settings = {
      user.name = "InfiniteNightmare";
      user.email = "742851870@qq.com";
    };
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
    # The firefoxpwa wrapper currently fails to build; the unwrapped package
    # still provides the native messaging manifest and connector Zen needs.
    nativeMessagingHosts = [ pkgs.firefoxpwa-unwrapped ];
    # Add any other native connectors here
  };

  home.sessionVariables = {
    GTK_USE_PORTAL = "1";
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

    # Disable version mismatch warnings for unstable branch
    enableReleaseChecks = false;
    # High contrast theme options:
    # - "catppuccin-mocha.yaml" - medium contrast
    # - "tokyo-night-dark.yaml" - Higher contrast dark theme
    # - "gruvbox-dark-hard.yaml" - Very high contrast
    # - "nord.yaml" - Good contrast with blue tones
    # - "solarized-dark.yaml" - Classic high contrast
    base16Scheme = "${inputs.stylix.inputs.tinted-schemes}/base16/tokyo-night-dark.yaml";
    polarity = "dark";

    # Reduce opacity for better contrast
    opacity = {
      terminal = 0.95;
      applications = 1.0;
      desktop = 0.9;
      popups = 0.92;
    };

    # Override colors for better contrast
    # override = {
    #   # Make background darker (pure black for maximum contrast)
    #   base00 = "000000"; # Pure black background
    #   # Make foreground much brighter (almost white)
    #   base05 = "f0f0f0"; # Very bright text
    #   # Brighter comments/disabled text
    #   base03 = "808080"; # Medium gray instead of dark gray
    # };

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

    targets.foot.colors.enable = false;
    targets.foot.opacity.enable = false;
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
  home.stateVersion = "26.05";

  # Disable nixpkgs version mismatch warning for unstable branch
  home.enableNixpkgsReleaseCheck = false;

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
