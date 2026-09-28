{
  pkgs,
  inputs,
  ...
}:

let
  # Deps lazy-imported by the skill scripts via PATH python3.
  pythonEnv = pkgs.python312.withPackages (
    ps: with ps; [
      pyyaml
      python-pptx
      pillow
    ]
  );
in
{
  home.packages = [ pythonEnv ];

  home.file.".codex/skills/drawio-skill".source =
    pkgs.runCommand "drawio-skill" { nativeBuildInputs = [ pythonEnv ]; }
      ''
        cp -r --no-preserve=mode ${inputs.drawio-skill}/skills/drawio-skill $out
        # upstream ships scripts non-executable; patchShebangs skips those
        chmod +x $out/scripts/*.py
        patchShebangs $out/scripts
      '';
}
