_: {
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      # --- File Management ---
      "inode/directory" = "yazi.desktop";

      # --- Browser and Web ---
      "text/html" = "zen-beta.desktop";
      "x-scheme-handler/http" = "zen-beta.desktop";
      "x-scheme-handler/https" = "zen-beta.desktop";
      "x-scheme-handler/chrome" = "zen-beta.desktop";
      "application/x-extension-htm" = "zen-beta.desktop";
      "application/x-extension-html" = "zen-beta.desktop";
      "application/x-extension-shtml" = "zen-beta.desktop";
      "application/xhtml+xml" = "zen-beta.desktop";
      "application/x-extension-xhtml" = "zen-beta.desktop";
      "application/x-extension-xht" = "zen-beta.desktop";

      # --- Proxy Utilities ---
      "x-scheme-handler/clash" = "clash-verge.desktop";
      "x-scheme-handler/clash-verge" = "clash-verge.desktop";

      # --- Media Players (mpv) ---
      "video/mp4" = "mpv.desktop";
      "video/x-matroska" = "mpv.desktop";
      "video/webm" = "mpv.desktop";
      "video/quicktime" = "mpv.desktop";
      "video/x-msvideo" = "mpv.desktop"; # avi
      "video/x-flv" = "mpv.desktop";
      "audio/mpeg" = "mpv.desktop"; # mp3
      "audio/flac" = "mpv.desktop";
      "audio/x-wav" = "mpv.desktop";
    };
  };
}
