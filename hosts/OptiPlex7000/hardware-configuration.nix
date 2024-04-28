# Do not modify this file!  It was generated by ‘nixos-generate-config’
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "vmd"
    "xhci_pci"
    "ahci"
    "nvme"
    "usbhid"
    "usb_storage"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ "amdgpu" ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/55773019-dbbb-40ef-9666-bf2c1bca9c09";
    fsType = "btrfs";
    options = [ "subvol=@,ssd,compress=zstd" ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/5A22-0B01";
    fsType = "vfat";
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/7741fbb1-344d-43cc-91a5-7be021e9a211";
    fsType = "btrfs";
    options = [ "compress=zstd" ];
  };

  fileSystems."/ext4-part" = {
    device = "/dev/sda2";
    fsType = "ext4";
  };

  fileSystems."/run/media/MyPassport" = {
    device = "/dev/sdc1";
    fsType = "ntfs-3g";
    options = [ "rw" ];
  };

  swapDevices = [ { device = "/dev/disk/by-uuid/2b2aa2fb-2ea9-46b5-bdb6-b37883042307"; } ];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp0s31f6.useDHCP = lib.mkDefault true;
  # networking.proxy = {
  # httpProxy = "http://127.0.0.1:7897";
  # httpsProxy = "http://127.0.0.1:7897";
  # allProxy = "socks5://127.0.0.1:7897";
  # };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
