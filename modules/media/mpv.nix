{ pkgs, ... }:
{
  programs.mpv = {
    enable = true;
    defaultProfiles = [ "gpu-hq" ];
    scripts = with pkgs.mpvScripts; [
      uosc # Modern UI
      thumbfast # On-screen thumbnail generation
      mpris # Keyboard media key support (play/pause)
      sponsorblock # Skip sponsored segments in YouTube videos (useful if playing URLs)
    ];

    config = {
      # Video decoding and rendering
      vo = "gpu";
      hwdec = "auto-safe";

      # UI styling (uosc will handle the UI)
      osd-bar = "no";
      border = "no";

      # Audio and Subtitles
      audio-display = "no";
      slang = "zh,chi,chs,cht,en,eng";
      alang = "jp,jpn,zh,chi,chs,cht,en,eng";
      sub-auto = "fuzzy";

      # Network caching for WebDAV playback
      cache = "yes";
      demuxer-max-bytes = "500M";
      demuxer-max-back-bytes = "100M";

      # Quality of life tweaks
      keep-open = "yes";
      save-position-on-quit = "yes";
      cursor-autohide = 1000;
    };
  };
}
