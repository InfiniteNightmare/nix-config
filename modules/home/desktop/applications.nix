{ pkgs, ... }:

let
  # Zotero currently needs XWayland for reliable rendering under Niri.
  zoteroX11 = pkgs.symlinkJoin {
    name = "zotero-x11";
    paths = [ pkgs.zotero ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/zotero \
        --set GDK_BACKEND x11 \
        --set MOZ_ENABLE_WAYLAND 0
    '';
  };
in
{
  home.packages = with pkgs; [
    zoteroX11
    obsidian
    motrix
    snipaste
    fluent-reader
    localsend
    freerdp
    remmina
    rustdesk
    czkawka
    wpsoffice-cn
    drawio
    qq
    wechat
    wemeet
    feishu
    taisei
    brave
    readest
  ];

  programs.zen-browser = {
    enable = true;
    policies = {
      DisableAppUpdate = true;
      DisableTelemetry = true;
    };
    # The firefoxpwa wrapper currently fails to build; the unwrapped package
    # still provides the native messaging manifest and connector Zen needs.
    nativeMessagingHosts = [ pkgs.firefoxpwa-unwrapped ];
  };
}
