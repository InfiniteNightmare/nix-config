{ pkgs, lib, ... }:

let
  # 10.0.6 self-pairs the vendored esr-140-bin (the runtime the retired upstream
  # tarball also shipped); the bundled launcher hardcodes MOZ_ENABLE_WAYLAND=1
  # where env can't beat it, so flip it in place — X11/XWayland stays reliable
  # under niri
  zotero = pkgs.zotero.overrideAttrs (old: {
    preFixup = (old.preFixup or "") + ''
      gappsWrapperArgs+=(--set GDK_BACKEND x11)
    '';
    postFixup = (old.postFixup or "") + ''
      substituteInPlace $out/lib/zotero \
        --replace-fail "MOZ_ENABLE_WAYLAND=1" "MOZ_ENABLE_WAYLAND=0"
    '';
  });

  # Closed beta; the artifact is auth-gated so the tarball is downloaded by hand
  # (lib/tern.nix has the requireFile flow).
  tern = pkgs.callPackage ../../../lib/tern.nix { };
in
{
  home.packages = with pkgs; [
    zotero
    obsidian
    keepassxc
    motrix
    fluent-reader
    localsend
    freerdp
    remmina
    # rustdesk
    czkawka
    wpsoffice-cn
    drawio
    qq
    wechat
    wemeet
    readest
    tern
  ];

  programs.zathura = {
    enable = true;
    # default "primary" only reaches middle-click paste; Ctrl+V reads CLIPBOARD
    options.selection-clipboard = "clipboard";
  };

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
