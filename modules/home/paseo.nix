{
  inputs,
  pkgs,
  ...
}:

let
  paseoDesktop = inputs.llm-agents.packages.${pkgs.stdenv.system}.paseo-desktop;
  paseoCli = pkgs.writeShellScriptBin "paseo" ''
    exec ${paseoDesktop}/share/paseo-desktop/packages/cli/bin/paseo "$@"
  '';
in
{
  home.packages = [
    paseoDesktop
    paseoCli
  ];
}
