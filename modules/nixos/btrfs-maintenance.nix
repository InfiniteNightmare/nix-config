{ ... }:

{
  services.btrfs.autoScrub = {
    enable = true;
    fileSystems = [
      "/"
      "/data"
    ];
    interval = "monthly";
    limit = "100M";
  };
}
