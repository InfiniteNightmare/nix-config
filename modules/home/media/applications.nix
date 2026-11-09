{
  pkgs,
  inputs,
  ...
}:
let
  # See flake.nix nixpkgs-aws-lc: pin splayer-next past the aws-lc-sys breakage.
  splayerPinned =
    let
      p = inputs.nixpkgs-aws-lc.legacyPackages.${pkgs.system}.splayer-next;
    in
    if p.version == "1.1.0" then
      p
    else
      throw "splayer-next pin drifted to ${p.version}; check if upstream added aws-lc to its expression, then re-pin or unpin (flake.nix nixpkgs-aws-lc)";
in
{
  home.packages = with pkgs; [
    pwvucontrol
    crosspipe
    mpvpaper
    splayerPinned
    obs-studio
  ];
}
