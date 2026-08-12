{ ... }:

{
  # The installer created this GC root while /nix was mounted below /mnt.
  # Declare the runtime profile tree as its canonical target.
  systemd.tmpfiles.rules = [
    "L+ /nix/var/nix/gcroots/profiles - - - - /nix/var/nix/profiles"
  ];
}
