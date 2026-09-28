# Makes the fcitx5 candidate panel work under the stylix theme:
#
# 1. Backports the SVG theme rendering fixes to fcitx5 5.1.22 — its new
#    renderer leaves vertically-stretched 9-patch tiles (the panel centre)
#    unpainted. Upstream: fcitx5 #1668 (d6552a5) and #1669 (b6497a5).
#
# 2. Replaces stylix's capsule artwork (pill radius 19 + drop shadow, SVGs
#    declaring 30px against a 60-unit viewBox) with plain rounded rects
#    whose curvature fits the layout margins, coloured from the palette.
#
# Delete this module once nixpkgs ships fcitx5 > 5.1.22 (the eval will throw
# as a reminder) — and re-check the highlight still fits if you keep the
# theme overrides without it.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Render inline mustache content with the stylix palette (stylix renders a
  # string `template` as mustache content directly).
  stylixSvg =
    {
      name,
      template,
    }:
    pkgs.runCommand name { } ''
      cat "${
        config.lib.stylix.colors {
          inherit template;
          extension = ".svg";
        }
      }" > "$out"
      # Unrendered placeholders mean renamed palette keys -> invisible panel.
      if grep -q '{{' "$out"; then
        echo "stylix palette placeholders did not render for ${name}; recheck or delete modules/home/fcitx5-stylix-fix.nix" >&2
        exit 1
      fi
    '';

  # Plain rounded rects with curvature that fits the layout margins below
  # (panel: inset 1.5 + radius 6; highlight: inset 3 + radius 5).
  panelSvg = stylixSvg {
    name = "panel.svg";
    template = ''
      <svg xmlns="http://www.w3.org/2000/svg" width="60" height="60" viewBox="0 0 60 60">
        <rect x="1.5" y="1.5" width="57" height="57" rx="6" style="fill:#{{base00-hex}}"/>
      </svg>
    '';
  };

  highlightSvg = stylixSvg {
    name = "highlight.svg";
    template = ''
      <svg xmlns="http://www.w3.org/2000/svg" width="60" height="60" viewBox="0 0 60 60">
        <rect x="3" y="3" width="54" height="54" rx="5" style="fill:#{{base02-hex}}"/>
      </svg>
    '';
  };

  margin = v: {
    Left = lib.mkForce v;
    Right = lib.mkForce v;
    Top = lib.mkForce v;
    Bottom = lib.mkForce v;
  };

  # Fail with instructions instead of an obscure patch rejection once
  # nixpkgs ships a fcitx5 release that no longer needs the backports.
  fcitx5Fixed =
    if pkgs.fcitx5.version != "5.1.22" then
      throw "fcitx5 ${pkgs.fcitx5.version} is in nixpkgs now; it should contain the SVG theme fixes (fcitx5 #1668/#1669). Delete modules/home/fcitx5-stylix-fix.nix."
    else
      pkgs.fcitx5.overrideAttrs (old: {
        patches =
          (old.patches or [ ])
          ++
            map
              (
                { rev, hash }:
                pkgs.fetchpatch {
                  url = "https://github.com/fcitx/fcitx5/commit/${rev}.patch";
                  inherit hash;
                }
              )
              [
                {
                  rev = "d6552a5b52b4ff75cae3fb6dc949ef379171b2b9";
                  hash = "sha256-osBaEk+I8gixvFk8p5HEzY3QgO2dgvjHKljUacDbO0o=";
                }
                {
                  rev = "b6497a5933f79b045b302c916e2c44683f26279d";
                  hash = "sha256-dOmYXc0VYuu/p1Nu9S/Yq9AwBsyrRKJ38YG3zswt2gM=";
                }
              ];
      });
in
{
  # Backport the SVG theme rendering fixes; see file comment.
  config = lib.mkMerge [
    {
      i18n.inputMethod.fcitx5.fcitx5-with-addons = pkgs.qt6Packages.fcitx5-with-addons.override {
        fcitx5 = fcitx5Fixed;
      };
    }

    (lib.mkIf config.stylix.targets.fcitx5.enable {
      i18n.inputMethod.fcitx5.themes.stylix = {
        panelImage = lib.mkForce panelSvg;
        highlightImage = lib.mkForce highlightSvg;
        theme = {
          # 9-patch margins only need to cover the 7.5 units of panel
          # curvature and stay under half the smallest popup height.
          "InputPanel/Background/Margin" = margin 12;
          "Menu/Background/Margin" = margin 12;
          # Highlight margins double as the selected-box expansion; keep the
          # box inside the panel (content margin is 10 left/right).
          "InputPanel/Highlight/Margin" = margin 10;
          "Menu/Highlight/Margin" = margin 8;
          "InputPanel/ContentMargin" = {
            Left = lib.mkForce 10;
            Right = lib.mkForce 10;
            Top = lib.mkForce 8;
            Bottom = lib.mkForce 8;
          };
        };
      };
    })
  ];
}
