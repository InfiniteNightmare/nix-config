{ pkgs, ... }:
{
  xdg.configFile."niri/config.kdl".text =
    let
      cfg = builtins.readFile ./config.kdl;
      polkitMate = "${pkgs.mate.mate-polkit}/libexec/polkit-mate-authentication-agent-1";
      polkitGnome = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
    in
    builtins.replaceStrings
      [
        "/usr/lib/mate-polkit/polkit-mate-authentication-agent-1"
        "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1"
      ]
      [
        polkitMate
        polkitGnome
      ]
      cfg;
}
