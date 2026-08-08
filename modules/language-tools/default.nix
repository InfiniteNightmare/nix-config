{
  config,
  lib,
  minimaxEnvFile,
  pkgs,
  ...
}:

let
  noctalia = lib.getExe config.programs.noctalia.package;

  minimaxClientSource = builtins.replaceStrings [ "@MINIMAX_ENV_FILE@" ] [ minimaxEnvFile ] (
    builtins.readFile ./minimax-client.py
  );

  minimaxClient = pkgs.writers.writePython3Bin "minimax-client" {
    flakeIgnore = [ "E501" ];
  } minimaxClientSource;

  languageToolsSource = builtins.replaceStrings [ "@NOCTALIA@" ] [ noctalia ] (
    builtins.readFile ./language-tools.sh
  );

  languageTools = pkgs.writeShellApplication {
    name = "language-tools";
    runtimeInputs = [
      minimaxClient
      pkgs.coreutils
      pkgs.findutils
      pkgs.gnugrep
      pkgs.libnotify
      pkgs.mpv
      pkgs.translate-shell
      pkgs.wl-clipboard
    ];
    text = languageToolsSource;
  };
in
{
  # Niri and Noctalia are long-lived, so keep one stable user-level command path
  # while Home Manager changes the immutable package behind it.
  home.file.".local/bin/language-tools".source = "${languageTools}/bin/language-tools";

  xdg.dataFile."noctalia/plugins/language-tools".source = ./noctalia-plugin;

  programs.noctalia.settings.plugins.enabled = [ "charname/language-tools" ];
}
