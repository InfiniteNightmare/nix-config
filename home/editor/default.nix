{ config, pkgs, ... }:
{
  programs = {

    vscode = {
      enable = true;
      # package = (pkgs.vscode.override { commandLineArgs = [ "--enable-wayland-ime" ]; });
      extensions = with pkgs.vscode-extensions; [
        bbenoist.nix
        eamodio.gitlens
        ms-python.python
        ms-vscode-remote.remote-ssh
        mkhl.direnv
      ];
    };

    helix = {
      enable = true;
      settings = {
        theme = "autumn_night_transparent";
        editor.cursor-shape = {
          normal = "block";
          insert = "bar";
          select = "underline";
        };
      };
      languages.language = [
        {
          name = "nix";
          auto-format = true;
          formatter.command = "${pkgs.nixfmt-rfc-style}/bin/nixfmt";
        }
      ];
      themes = {
        autumn_night_transparent = {
          "inherits" = "autumn_night";
          "ui.background" = { };
        };
      };
    };
  };
}
