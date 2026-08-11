{
  config,
  lib,
  pkgs,
  ...
}:
let
  proxySettings = import ../../../lib/proxy-settings.nix;
  profileScript = "${config.home.homeDirectory}/.local/share/io.github.clash-verge-rev.clash-verge-rev/profiles/sN9eG16QuHvB.js";
  backupScript = "${config.home.homeDirectory}/.config/proxy/ai-us-clash-enhance.js";
  renderClashProfile = pkgs.writeShellApplication {
    name = "render-clash-vps-profile";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      runtime_dir="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
      secret="$runtime_dir/agenix/clash-vps-client"

      if [ ! -r "$secret" ]; then
        echo "Clash VPS secret is unavailable" >&2
        exit 1
      fi

      render_clash_script() {
        target="$1"
        target_dir="$(dirname "$target")"

        mkdir -p "$target_dir"
        temporary="$(mktemp --suffix=.js "$target_dir/.clash-enhance.XXXXXX")"

        if ! ${pkgs.nodejs}/bin/node ${./render-clash-enhance.js} "$secret" > "$temporary"; then
          rm -f "$temporary"
          echo "failed to render Clash enhancement for $target" >&2
          return 1
        fi

        chmod 600 "$temporary"
        if ! ${pkgs.nodejs}/bin/node --check "$temporary" >/dev/null; then
          rm -f "$temporary"
          echo "rendered Clash enhancement is invalid for $target" >&2
          return 1
        fi

        if [ -e "$target" ] && cmp -s "$temporary" "$target"; then
          rm -f "$temporary"
          return 0
        fi

        mv -f "$temporary" "$target"
      }

      render_clash_script ${lib.escapeShellArg profileScript}
      render_clash_script ${lib.escapeShellArg backupScript}
    '';
  };
in
{
  # This user-specific secret is decrypted only after the home directory is
  # available. System activation runs too early to read the user's SSH key.
  age.identityPaths = [ "${config.home.homeDirectory}/.ssh/id_ed25519" ];
  age.secrets.clash-vps-client = {
    file = ../../../secrets/clash-vps-client.age;
    mode = "0400";
  };

  systemd.user.services.clash-vps-profile = {
    Unit = {
      Description = "Render the Clash VPS profile after decrypting its credentials";
      Requires = [ "agenix.service" ];
      After = [ "agenix.service" ];
      PartOf = [ "agenix.service" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = lib.getExe renderClashProfile;
      RemainAfterExit = true;
    };
    Install.WantedBy = [ "default.target" ];
  };

  home.file.".config/proxy/ai-us-terminal.sh" = {
    force = true;
    text = ''
      export http_proxy="${proxySettings.httpProxy}"
      export https_proxy="${proxySettings.httpsProxy}"
      export all_proxy="${proxySettings.allProxy}"
      export no_proxy="${proxySettings.noProxy}"

      export HTTP_PROXY="$http_proxy"
      export HTTPS_PROXY="$https_proxy"
      export ALL_PROXY="$all_proxy"
      export NO_PROXY="$no_proxy"
    '';
  };
}
