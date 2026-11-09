{ pkgs, ... }:
# Crash-loops trip systemd's start rate limit and leave the unit failed until
# manually reset (noctalia's 2026-10 glibc breakage sat there all day). This
# probe restarts such units on a cadence, bounding the worst-case downtime.
# It only targets the "failed" state: normal restart loops stay untouched.
{
  systemd.user.services.service-watchdog = {
    Unit.Description = "Self-heal critical user services";
    Service = {
      Type = "oneshot";
      ExecStart =
        let
          probe = pkgs.writeShellScript "service-watchdog" ''
            for unit in noctalia.service ssh-jump-tunnel.service; do
              state=$(systemctl --user show -P ActiveState "$unit")
              if [ "$state" = failed ]; then
                echo "resetting failed unit $unit" | systemd-cat -t service-watchdog -p warning
                systemctl --user reset-failed "$unit"
                systemctl --user start "$unit" \
                  || echo "watchdog failed to start $unit" | systemd-cat -t service-watchdog -p err
              fi
            done
          '';
        in
        "${probe}";
    };
  };

  systemd.user.timers.service-watchdog = {
    Unit.Description = "Periodically self-heal critical user services";
    Timer = {
      OnCalendar = "*:0/5";
      Unit = "service-watchdog.service";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
