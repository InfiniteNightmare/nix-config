{
  services.borgbackup.jobs.home-critical = {
    paths = [
      "/home/charname/Projects"
      "/home/charname/Zotero"
    ];
    repo = "/data/backup";
    doInit = true;
    encryption.mode = "none";
    compression = "auto,zstd";
    startAt = "*-*-* 03:00:00";
    persistentTimer = true;
    prune.keep = {
      within = "1d";
      daily = 7;
      weekly = 8;
    };
  };
}
