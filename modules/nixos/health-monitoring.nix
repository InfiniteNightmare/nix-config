{
  services = {
    smartd = {
      enable = true;
      autodetect = true;
    };

    journald.settings.Journal = {
      SystemMaxUse = "1G";
      MaxRetentionSec = "30day";
    };
  };

  systemd.coredump.settings.Coredump.MaxUse = "256M";
}
