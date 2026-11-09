{
  config,
  pkgs,
  ...
}:

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

  # Serialized after the weekly store optimise so both IO-heavy jobs share one night.
  systemd.services.home-dedupe = {
    description = "Reflink Dedupe of /home/charname";
    wants = [ "nix-optimise.service" ];
    after = [ "nix-optimise.service" ];
    unitConfig.ConditionACPower = true;
    serviceConfig = {
      Type = "oneshot";
      User = "charname";
      Group = "users";
      Nice = 19;
      CPUSchedulingPolicy = "idle";
      IOSchedulingClass = "idle";
      TimeoutStartSec = "4h";
    };
    path = [ pkgs.duperemove ];
    script = ''
      exec duperemove -d -r --hashfile=/home/charname/.cache/duperemove-home.hash /home/charname
    '';
  };

  systemd.timers.home-dedupe = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true;
      RandomizedDelaySec = 1800;
    };
  };
}
