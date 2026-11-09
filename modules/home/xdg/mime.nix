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

      # --- App deep links ---
      "x-scheme-handler/zcode" = "zcode.desktop";
      "x-scheme-handler/codex" = "chatgpt.desktop";

      # --- Media Players (mpv) ---
      "video/mp4" = "mpv.desktop";
      "video/x-matroska" = "mpv.desktop";
      "video/matroska" = "mpv.desktop"; # file(1) emits this alias for some mkv EBML headers
      "video/webm" = "mpv.desktop";
      "video/quicktime" = "mpv.desktop";
      "video/x-msvideo" = "mpv.desktop"; # avi
      "video/x-flv" = "mpv.desktop";
      "audio/mpeg" = "mpv.desktop"; # mp3
      "audio/flac" = "mpv.desktop";
      "audio/x-wav" = "mpv.desktop";

      # --- PDF (zathura) ---
      "application/pdf" = "zathura.desktop";

      # --- Markdown/text (neovide) ---
      "text/markdown" = "neovide.desktop";
      "text/plain" = "neovide.desktop";

      # --- Images (swayimg) ---
      "image/png" = "swayimg.desktop";
      "image/jpeg" = "swayimg.desktop";
      "image/jpg" = "swayimg.desktop";
      "image/gif" = "swayimg.desktop";
      "image/webp" = "swayimg.desktop";
      "image/avif" = "swayimg.desktop";
      "image/jxl" = "swayimg.desktop";
      "image/heif" = "swayimg.desktop";
      "image/svg+xml" = "swayimg.desktop";
      "image/bmp" = "swayimg.desktop";
      "image/tiff" = "swayimg.desktop";
    };
  };
}
