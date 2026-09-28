{ pkgs, ... }:
{
  # ZCode's built-in SSH client cannot follow ProxyJump, so a local forward
  # stands in for the jump: ZCode connects to localhost:2222, which lands on
  # ali-gpu-server-133's sshd through macbook.
  systemd.user.services.ssh-jump-tunnel = {
    Unit = {
      Description = "SSH tunnel to ali-gpu-server-133 through the macbook jump host";
      # The jump host is a DHCP laptop: unreachable periods are normal, so
      # retry forever instead of tripping systemd's default start-rate limit.
      StartLimitIntervalSec = 0;
    };
    Service = {
      # "macbook" is an ssh_config alias, not a literal address: every restart
      # re-reads ~/.ssh/config, so manually updating the jump IP there takes
      # effect on the next reconnect. The forward destination must stay a
      # literal address because macbook resolves it on its own side.
      ExecStart = ''
        ${pkgs.openssh}/bin/ssh -N \
          -o BatchMode=yes \
          -o ExitOnForwardFailure=yes \
          -o ServerAliveInterval=15 \
          -o ServerAliveCountMax=3 \
          -o ConnectTimeout=15 \
          -L 2222:11.167.35.133:22 \
          macbook
      '';
      Restart = "always";
      RestartSec = 5;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
