{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # Archives
    zip
    xz
    unzip
    p7zip
    pigz
    unrar

    # Command-line utilities
    ripgrep
    jq
    yq-go
    fzf
    cowsay
    file
    which
    tree
    gnused
    gnutar
    gawk
    zstd
    gnupg
    glow

    # Networking
    mtr
    iperf3
    dnsutils
    ldns
    aria2
    socat
    nmap
    ipcalc
    traceroute

    # Monitoring and diagnostics
    btop
    iotop
    iftop
    strace
    lsof
    sysstat
    lm_sensors
    ethtool
    pciutils
    usbutils
    hdparm
    cpu-x
    dmidecode
    smartmontools
    nvme-cli
    parted

    # Terminal applications
    waveterm
    warp-terminal
    gtypist
    ttyper
  ];
}
