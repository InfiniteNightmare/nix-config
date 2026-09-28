{
  pkgs,
  ...
}:
let
  # Chroma upscaled jointly with luma: removes the color bleeding visible
  # on line art at 4:2:0. Unlike upscaling shaders this runs at any
  # resolution — chroma planes are always half-res — so it also benefits
  # 1080p+ sources. Authoritative copy is igv's gist, pinned to a revision
  # for hash stability.
  krigBilateral = pkgs.fetchurl {
    url = "https://gist.githubusercontent.com/igv/a015fc885d5c22e6891820ad89555637/raw/d7f39734d6aff4c0989f32a4530b1b010e64bda3/KrigBilateral.glsl";
    hash = "sha256-ikeYq7d7g2Rvzg1xmF3f0UyYBuO+SG6Px/WlqL2UDLA=";
  };
in
{
  programs.mpv = {
    enable = true;
    defaultProfiles = [ "high-quality" ];
    scripts = with pkgs.mpvScripts; [
      uosc # Modern UI
      thumbfast # On-screen thumbnail generation
      mpris # Keyboard media key support (play/pause)
      sponsorblock # Skip sponsored segments in YouTube videos (useful if playing URLs)
    ];

    config = {
      # gpu-next (libplacebo) supersedes vo=gpu with a better scaling/HDR pipeline
      vo = "gpu-next";
      hwdec = "auto-safe";

      # Scalers come from the high-quality profile (ewa_lanczossharp);
      # deband is off by default in current mpv and smooths banding in
      # 8-bit sources
      deband = "yes";

      # Chroma upscaler, see comment above
      glsl-shaders = "${krigBilateral}";

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
