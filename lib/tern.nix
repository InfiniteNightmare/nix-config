# Tern is closed beta: build.stencil.so artifacts 302 to auth.stencil.so for
# unauthenticated requests, so no Nix fetcher can pull them. requireFile pins a
# tarball downloaded in a signed-in browser; after each bump (version + build id
# + hash together) run:
#   nix hash file --type sha256 --sri ~/Downloads/Tern-<version>-linux-x86_64.tar.gz
#   nix-store --add-fixed sha256 ~/Downloads/Tern-<version>-linux-x86_64.tar.gz
{
  lib,
  stdenv,
  requireFile,
  autoPatchelfHook,
  makeWrapper,
  versionCheckHook,
  desktop-file-utils,
  git,
  glib,
  gtk3,
  xdg-utils,
  zenity,
  vulkan-loader,
  libGL,
  libxkbcommon,
  libxcb,
  wayland,
  webkitgtk_4_1,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "tern";
  version = "0.8.3";

  src = requireFile {
    name = "Tern-${finalAttrs.version}-linux-x86_64.tar.gz";
    url = "https://build.stencil.so/d/tern/20261012-142610-e2b8656/Tern-${finalAttrs.version}-linux-x86_64.tar.gz";
    hash = "sha256-vMICgHolxxhYVhofV+A95F+94ZE4STAuNKLwo2xs/nk=";
  };

  # The archive holds a single tern/tern.
  sourceRoot = "tern";

  dontConfigure = true;
  dontBuild = true;

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    # setup hook: update-desktop-database over the shipped entries
    desktop-file-utils
  ];

  # Beyond glibc (from stdenv) the binary links only libstdc++/libgcc_s.
  buildInputs = [ stdenv.cc.cc.lib ];

  # wgpu dlopens Vulkan/EGL/Wayland/xcb instead of linking them (no DT_NEEDED
  # entries for patchelf to fix), and browser panes dlopen WebKitGTK; the GPU
  # driver lives outside the store, hence /run/opengl-driver/lib.
  appendRunpaths = [
    (lib.makeLibraryPath [
      vulkan-loader
      libGL
      libxkbcommon
      libxcb
      wayland
      webkitgtk_4_1
    ])
    "/run/opengl-driver/lib"
  ];

  installPhase = ''
    runHook preInstall
    install -Dm755 tern $out/bin/tern
    # `tern register` writes Exec with the inner binary path, bypassing this
    # wrapper, so the entries ship here instead; icons stay in
    # ~/.local/share/icons from the one-time register.
    mkdir -p $out/share/applications
    substituteAll ${./tern.desktop} $out/share/applications/so.stencil.tern.desktop
    substituteAll ${./tern-open.desktop} $out/share/applications/so.stencil.tern.open.desktop
    # Keep the auth-gated tarball inside the runtime closure: an unrooted
    # requireFile input gets GC'd (nixos-clean-switch does exactly that) and
    # breaks the next rebuild.
    ln -s $src $out/share/.tern-tarball
    runHook postInstall
  '';

  # `tern plugin install` shells out to git; `tern register` to the desktop
  # entry, icon and MIME caches; the appearance module reads the color-scheme
  # portal through gdbus. ureq (tern's HTTP client) is built without the
  # socks-proxy feature yet honors ALL_PROXY first: with socks5h there it
  # fails every request with a fake "Connection refused"; unsetting it leaves
  # the working HTTPS_PROXY=http:// form.
  postFixup = ''
    mv $out/bin/tern $out/bin/.tern-wrapped
    makeWrapper $out/bin/.tern-wrapped $out/bin/tern \
      --unset ALL_PROXY \
      --unset all_proxy \
      --prefix PATH : ${
        lib.makeBinPath [
          desktop-file-utils
          git
          glib
          gtk3
          xdg-utils
          # tern's close/quit confirmation dialog shells out to zenity
          zenity
        ]
      }
  '';

  # Running the wrapped binary is the only check that the pinned artifact still
  # loads against this nixpkgs.
  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgramArg = "--version";

  meta = {
    description = "Stencil's Rust-native multiplexing terminal (closed beta)";
    homepage = "https://stencil.so/tern";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "tern";
    platforms = [ "x86_64-linux" ];
  };
})
