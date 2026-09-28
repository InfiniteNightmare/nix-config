{ inputs, pkgs, ... }:

let
  proxySettings = import ../../../lib/proxy-settings.nix;

  prepareServer = pkgs.writeShellApplication {
    name = "prepare-zotero-pdf2zh-server";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.rsync
    ];
    text = ''
      : "''${STATE_DIRECTORY:?systemd did not provide STATE_DIRECTORY}"
      server_dir="$STATE_DIRECTORY/server"
      install -d -m 0700 "$server_dir"

      # Refresh application code while retaining generated configuration,
      # translated files, and uv-managed translation environments.
      rsync --archive --delete \
        --exclude '/config/config.json' \
        --exclude '/config/config.toml' \
        --exclude '/config/venv.json' \
        --exclude '/translated/' \
        --exclude '/zotero-pdf2zh-venv/' \
        --exclude '/zotero-pdf2zh-next-venv/' \
        ${inputs.zotero-pdf2zh}/server/ "$server_dir/"

      chmod -R u+rwX,go-rwx "$server_dir"
    '';
  };
in
{
  systemd.user.services.zotero-pdf2zh = {
    Unit = {
      Description = "Local Zotero PDF2zh server";
      Documentation = "https://github.com/guaguastandup/zotero-pdf2zh";
    };

    Service = {
      Type = "simple";
      StateDirectory = "zotero-pdf2zh";
      WorkingDirectory = "%S/zotero-pdf2zh";
      ExecStartPre = "${prepareServer}/bin/prepare-zotero-pdf2zh-server";
      ExecStart = "${pkgs.uv}/bin/uv run --python ${pkgs.python312}/bin/python --with-requirements %S/zotero-pdf2zh/server/requirements.txt %S/zotero-pdf2zh/server/server.py --host 127.0.0.1 --port 8890 --env_tool uv --check_update false --update_source gitee --enable_mirror true --mirror_source https://mirrors.ustc.edu.cn/pypi/simple";
      Restart = "on-failure";
      RestartSec = 5;
      UMask = "0077";
      Environment = [
        "LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ]}"
        # BabelDOC assets fail through the local Clash proxy but work directly.
        "NO_PROXY=${proxySettings.noProxy},raw.githubusercontent.com"
        "PATH=${pkgs.lib.makeBinPath [ pkgs.uv ]}"
        "PYTHONUNBUFFERED=1"
        "no_proxy=${proxySettings.noProxy},raw.githubusercontent.com"
      ];
    };

    Install.WantedBy = [ "default.target" ];
  };
}
