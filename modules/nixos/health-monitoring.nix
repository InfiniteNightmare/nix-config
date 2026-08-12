{
  services = {
    smartd = {
      enable = true;
      autodetect = true;
    };

    journald.extraConfig = ''
      SystemMaxUse=1G
      MaxRetentionSec=30day
    '';
  };

  systemd.coredump.settings.Coredump.MaxUse = "256M";
}
