{ config, pkgs, ... }:

let
  yaziFileManagerBridge = pkgs.writers.writePython3Bin "yazi-file-manager-bridge" {
    libraries = [ pkgs.python3Packages.dbus-fast ];
    flakeIgnore = [ "E501" ];
  } (builtins.readFile ./yazi-file-manager.py);
  yaziFileManagerBridgeExec = "${yaziFileManagerBridge}/bin/yazi-file-manager-bridge --footclient=${pkgs.foot}/bin/footclient --yazi=${config.programs.yazi.finalPackage}/bin/yazi";
in
{
  # Override Yazi's Terminal=true entry because Niri's generic xdg-open path
  # executes desktop entries without launching their requested terminal.
  xdg.desktopEntries.yazi = {
    name = "Yazi File Manager";
    genericName = "File Manager";
    comment = "Browse files with Yazi in foot";
    icon = "yazi";
    exec = "${pkgs.foot}/bin/footclient --no-wait --app-id=yazi --title=yazi ${config.programs.yazi.finalPackage}/bin/yazi -- %f";
    terminal = false;
    startupNotify = false;
    mimeType = [ "inode/directory" ];
    categories = [
      "System"
      "FileManager"
      "FileTools"
    ];
    settings.Keywords = "File;Manager;Explorer;Browser;";
  };

  # Applications such as browsers use FileManager1 for "show in folder"
  # instead of consulting the inode/directory MIME association.
  systemd.user.services.yazi-file-manager = {
    Unit = {
      Description = "Yazi implementation of org.freedesktop.FileManager1";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };

    Service = {
      Type = "dbus";
      BusName = "org.freedesktop.FileManager1";
      ExecStart = yaziFileManagerBridgeExec;
    };
  };

  xdg.dataFile."dbus-1/services/org.freedesktop.FileManager1.service".text = ''
    [D-BUS Service]
    Name=org.freedesktop.FileManager1
    Exec=${yaziFileManagerBridgeExec}
    SystemdService=yazi-file-manager.service
  '';
}
