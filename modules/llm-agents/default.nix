{ pkgs, inputs, ... }:
let
  llmAgentsPkgs = inputs.llm-agents.packages.${pkgs.stdenv.system};
in
{
  home.packages = with llmAgentsPkgs; [
    opencode
    claude-code
    codex
    rtk
    herdr
    agent-deck
  ];
}
