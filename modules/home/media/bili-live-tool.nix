{ lib, pkgs, ... }:
let
  version = "2.3.17";

  src = pkgs.fetchFromGitHub {
    owner = "ChaceQC";
    repo = "bilibili_live_stream_code";
    rev = "v${version}";
    hash = "sha256-czLVa6jKTetq0Gs5L/pjYvseZA2gFkBhB9DxdJQH0GU=";
  };

  python = pkgs.python3;

  pythonEnv = python.withPackages (
    ps: with ps; [
      aiohttp
      brotli
      brotlipy
      cffi
      pillow
      protobuf
      pycairo
      pygobject3
      pystray
      pywebview
      requests
    ]
  );

  frontend = pkgs.buildNpmPackage {
    pname = "bili-live-tool-frontend";
    inherit version src;

    sourceRoot = "${src.name}/frontend";
    npmDepsHash = "sha256-bsEcf5OVXiTOOgnS/l5zwmoRQSmywztj7gsrhhzhNuA=";

    postPatch = ''
      substituteInPlace src/api/bridge.js \
        --replace-fail "setTimeout(() => resolve(), 3000);" "setTimeout(() => resolve(), 20000);"

      substituteInPlace src/components/QrCodeLogin.vue \
        --replace-fail "qrStatusText.value = '获取失败，请检查网络';" "qrStatusText.value = '后端初始化中，正在重试...'; setTimeout(loadQrCode, 1200);"
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r dist/* $out/
      runHook postInstall
    '';
  };

  runtimeLibs = with pkgs; [
    stdenv.cc.cc.lib
    alsa-lib
    dbus
    expat
    cairo
    at-spi2-core
    fontconfig
    freetype
    glib
    harfbuzz
    libdrm
    libglvnd
    libx11
    libxcomposite
    libxcursor
    libxdamage
    libxext
    libxfixes
    libxi
    libxkbcommon
    libxrandr
    libxrender
    libxtst
    libxcb
    libxcb-cursor
    libxcb-image
    libxcb-keysyms
    libxcb-render-util
    libxcb-util
    libxcb-wm
    mesa
    nspr
    nss
    gtk3
    libsoup_3
    webkitgtk_4_1
    wayland
    xkeyboard_config
    zlib
  ];

  giTypelibPath = lib.makeSearchPath "lib/girepository-1.0" [
    pkgs.gobject-introspection
    pkgs.glib
    pkgs.at-spi2-core
    pkgs.gtk3
    pkgs.libsoup_3
    pkgs.webkitgtk_4_1
    pkgs.cairo
    pkgs.gdk-pixbuf
    pkgs.pango.out
    pkgs.harfbuzz
  ];

  xdgDataDirs = lib.makeSearchPath "share" [
    pkgs.gsettings-desktop-schemas
    pkgs.gtk3
    pkgs.hicolor-icon-theme
    pkgs.adwaita-icon-theme
  ];

  launcherScript = pkgs.writeShellScript "bili-live-tool" ''
    set -eu

    runtimeRoot="''${XDG_STATE_HOME:-$HOME/.local/state}/bili-live-tool-src"
    runtimeDir="$runtimeRoot/${version}"
    sourceDir="@sourceDir@"
    sourceStampFile="$runtimeDir/.nix-source-path"

    if [ ! -f "$runtimeDir/main.py" ] || [ ! -f "$sourceStampFile" ] || [ "$(cat "$sourceStampFile")" != "$sourceDir" ]; then
      ${pkgs.coreutils}/bin/mkdir -p "$runtimeRoot"
      ${pkgs.coreutils}/bin/rm -rf "$runtimeDir"
      ${pkgs.coreutils}/bin/cp -r "$sourceDir" "$runtimeDir"
      ${pkgs.coreutils}/bin/chmod -R u+rwX "$runtimeDir"
      printf '%s\n' "$sourceDir" > "$sourceStampFile"
    fi

    export PYTHONUNBUFFERED=1
    export PYWEBVIEW_GUI=gtk
    export GDK_BACKEND="wayland,x11"
    export GI_TYPELIB_PATH="${giTypelibPath}"
    export XDG_DATA_DIRS="${xdgDataDirs}:''${XDG_DATA_DIRS:-}"
    export LD_LIBRARY_PATH="${lib.makeLibraryPath runtimeLibs}:''${LD_LIBRARY_PATH:-}"

    cd "$runtimeDir"
    exec "${pythonEnv}/bin/python" "$runtimeDir/main.py" "$@"
  '';

  desktopFile = pkgs.writeText "bili-live-tool.desktop" ''
    [Desktop Entry]
    Type=Application
    Name=BiliLiveTool
    Comment=Bilibili live stream helper
    Exec=${pkgs.runtimeShell} @launcher@
    Icon=bili-live-tool
    Terminal=false
    StartupNotify=true
    Categories=Network;AudioVideo;Utility;
  '';

  biliLiveTool = pkgs.stdenvNoCC.mkDerivation {
    pname = "bili-live-tool";
    inherit version src;

    nativeBuildInputs = [ pkgs.imagemagick ];

    installPhase = ''
            runHook preInstall

            mkdir -p "$out/lib/bili-live-tool" "$out/bin" "$out/share/icons/hicolor/256x256/apps" "$out/share/applications"

            cp -r backend "$out/lib/bili-live-tool/backend"
            cp main.py "$out/lib/bili-live-tool/main.py"
            cp bilibili.ico "$out/lib/bili-live-tool/bilibili.ico"
            mkdir -p "$out/lib/bili-live-tool/frontend"
            cp -r "${frontend}" "$out/lib/bili-live-tool/frontend/dist"

            cat > "$out/lib/bili-live-tool/backend/services/auth_service.py" <<'EOF'
      import logging
      import time


      logger = logging.getLogger("AuthService")


      class AuthService:
          def __init__(self, api_client, user_service, live_service, session_state):
              self.api = api_client
              self.user_service = user_service
              self.live_service = live_service
              self.state = session_state

          def get_login_qrcode(self):
              last_error = None
              for attempt in range(3):
                  success, res = self.api.get_passport_qrcode()
                  if success and res.get("code") == 0 and res.get("data", {}).get("url"):
                      return {"code": 0, "data": res["data"]}

                  code = res.get("code", -1) if isinstance(res, dict) else -1
                  msg = res.get("msg") or res.get("message") or "二维码接口返回异常" if isinstance(res, dict) else "二维码接口返回异常"
                  last_error = {"code": code, "msg": msg}
                  logger.warning("QR code request failed (attempt %s): code=%s msg=%s", attempt + 1, code, msg)

                  if attempt < 2:
                      time.sleep(0.6)

              return {"code": last_error["code"], "msg": last_error["msg"]}

          def poll_login_status(self, key):
              success, res, cookies = self.api.poll_passport_qrcode(key)
              if not success:
                  return {"code": -1, "msg": res.get("msg", "网络请求失败")}

              data = res.get("data", {})
              if data.get("code") == 0:
                  try:
                      self.state.clear()
                      self.api.update_cookies(cookies)
                      csrf = cookies.get("bili_jct", "")
                      room_id = self.user_service.fetch_room_id(cookies)
                      if not room_id:
                          return {"code": -1, "msg": "获取直播间ID失败"}

                      ok, full_data = self.user_service.fetch_full_user_data()
                      if ok:
                          uid = str(cookies.get("DedeUserID"))
                          cookie_str = "; ".join([f"{k}={v}" for k, v in cookies.items()])
                          saved_user = self.user_service.save_user_data(uid, full_data, cookie_str, room_id, csrf)
                          self.live_service._refresh_partitions_internal()
                          return {"code": 0, "data": saved_user}

                      return {"code": -1, "msg": "获取用户信息失败"}
                  except Exception as e:
                      return {"code": -1, "msg": str(e)}

              return {"code": data.get("code", -1), "msg": data.get("message", "二维码状态异常")}
      EOF

            magick "bilibili.ico" -resize 256x256 "$out/share/icons/hicolor/256x256/apps/bili-live-tool.png"

            cp "${launcherScript}" "$out/bin/bili-live-tool"
            substituteInPlace "$out/bin/bili-live-tool" --replace-fail "@sourceDir@" "$out/lib/bili-live-tool"
            chmod 0555 "$out/bin/bili-live-tool"

            cp "${desktopFile}" "$out/share/applications/bili-live-tool.desktop"
            substituteInPlace "$out/share/applications/bili-live-tool.desktop" --replace-fail "@launcher@" "$out/bin/bili-live-tool"

            runHook postInstall
    '';

    meta = {
      description = "Bilibili live stream key tool (source runtime)";
      homepage = "https://github.com/ChaceQC/bilibili_live_stream_code";
      license = lib.licenses.asl20;
      platforms = [ "x86_64-linux" ];
      mainProgram = "bili-live-tool";
    };
  };
in
{
  home.packages = [ biliLiveTool ];
}
