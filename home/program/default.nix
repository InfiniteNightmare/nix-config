{ pkgs, ... }:
{
  programs.vscode = {
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
}
