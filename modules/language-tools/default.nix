{
  config,
  lib,
  pkgs,
  ...
}:

let
  noctalia = lib.getExe config.programs.noctalia.package;
  minimaxEnvFile = config.age.secrets.minimax-env.path;

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
  # This credential is only consumed by user-session tools. Decrypt it after
  # /home is mounted so the user's SSH identity is available across reboots.
  age.identityPaths = lib.mkDefault [ "${config.home.homeDirectory}/.ssh/id_ed25519" ];
  age.secrets.minimax-env = {
    file = ../../secrets/minimax-env.age;
    mode = "0400";
  };

  # Niri and Noctalia are long-lived, so keep one stable user-level command path
  # while Home Manager changes the immutable package behind it.
  home.file.".local/bin/language-tools".source = "${languageTools}/bin/language-tools";

  xdg.dataFile."noctalia/plugins/language-tools".source = ./noctalia-plugin;

  programs.noctalia.settings.plugins.enabled = [ "charname/language-tools" ];
}
