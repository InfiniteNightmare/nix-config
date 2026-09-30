{
  pkgs,
  inputs,
  ...
}:

let
  llmAgentsPkgs = inputs.llm-agents.packages.${pkgs.stdenv.system};

  # codex's app-server daemon requires the CLI to be a complete package
  # (codex-package.json beside bin/codex, target must match the ELF); nix
  # ships a bare ELF under libexec/codex, so synthesize the layout. Re-run
  # `codex app-server daemon update` once per version bump to re-pin.
  codexPackage = pkgs.runCommand "codex-${llmAgentsPkgs.codex.version}-package" { } ''
    # upstream shipping a complete layout makes this wrapper redundant
    if [ -e ${llmAgentsPkgs.codex}/codex-package.json ]; then
      echo "codex now ships a complete package layout upstream; remove the codexPackage wrapper in modules/home/llm-agents.nix" >&2
      exit 1
    fi
    # all real files: /proc/self/exe must resolve inside the package, the
    # installer rejects links escaping the package root, and the build
    # sandbox cannot hardlink across mounts
    mkdir -p $out/bin $out/codex-path $out/codex-resources
    cp ${llmAgentsPkgs.codex}/libexec/codex/bin/codex $out/bin/codex
    cp ${llmAgentsPkgs.codex}/libexec/codex/bin/codex-code-mode-host $out/bin/codex-code-mode-host
    cp ${pkgs.ripgrep}/bin/rg $out/codex-path/rg
    cp ${pkgs.bubblewrap}/bin/bwrap $out/codex-resources/bwrap
    echo '{"version":"${llmAgentsPkgs.codex.version}","target":"${pkgs.stdenv.hostPlatform.config}","entrypoint":"bin/codex"}' > $out/codex-package.json
  '';
in
{
  home.packages = with llmAgentsPkgs; [
    opencode
    claude-code
    codexPackage
    chatgpt
    dsh
    qoder-cli
    herdr
    agent-deck
    paseo-desktop
    zcode
  ];
}
