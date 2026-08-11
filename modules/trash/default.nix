{ pkgs, ... }:
{
  home.packages = [ pkgs.trash-cli ];

  systemd.user = {
    services.trash-cleanup = {
      Unit.Description = "Remove trash entries older than 30 days";
      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.trash-cli}/bin/trash-empty -f 30";
        Nice = 10;
        IOSchedulingClass = "idle";
      };
    };

    timers.trash-cleanup = {
      Unit.Description = "Clean old trash entries weekly";
      Timer = {
        OnCalendar = "weekly";
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
