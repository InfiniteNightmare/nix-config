{
  description = "My NixOS flake configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    noctalia = {
      url = "github:noctalia-dev/noctalia-shell";
      # Keep Noctalia's own nixpkgs input so its derivation matches upstream Cachix.
    };

    niri.url = "github:sodiboo/niri-flake";

    agenix = {
      url = "github:yaxitech/ragenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    llm-agents.url = "github:numtide/llm-agents.nix";

    # Declarative neovim configuration module (programs.nixvim)
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # The server is copied into writable user state at activation time. Keeping
    # it as a flake input makes the normal `nix flake update` upgrade it too.
    zotero-pdf2zh = {
      url = "github:guaguastandup/zotero-pdf2zh";
      flake = false;
    };

    # Codex draw.io skill, linked read-only into ~/.codex/skills; a normal
    # `nix flake update` syncs it from upstream.
    drawio-skill = {
      url = "github:Agents365-ai/drawio-skill";
      flake = false;
    };

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      # IMPORTANT: we're using "libgbm" and is only available in unstable so ensure
      # to have it up-to-date or simply don't specify the nixpkgs input
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ nixpkgs, ... }:
    let
      system = "x86_64-linux";
      userName = "charname";
      pkgs = nixpkgs.legacyPackages.${system};
      moduleFiles = import ./lib/module-files.nix { inherit (nixpkgs) lib; };
      thinkbook = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs moduleFiles userName;
        };
        modules = [
          ./hosts/thinkbook
        ]
        ++ moduleFiles ./modules/nixos
        ++ [
          inputs.nixos-hardware.nixosModules.common-cpu-amd
          inputs.nixos-hardware.nixosModules.common-gpu-amd
          inputs.nixos-hardware.nixosModules.common-pc-laptop
          inputs.nixos-hardware.nixosModules.common-pc-laptop-ssd

          inputs.niri.nixosModules.niri
        ];
      };
    in
    {
      formatter.${system} = pkgs.nixfmt-tree;

      checks.${system} = {
        thinkbook = thinkbook.config.system.build.toplevel;

        lifecycle-scripts =
          pkgs.runCommand "nixos-lifecycle-scripts-check"
            {
              nativeBuildInputs = [
                pkgs.bash
                pkgs.coreutils
                pkgs.findutils
                pkgs.gawk
                pkgs.gnugrep
                pkgs.gnused
                pkgs.jq
                pkgs.shellcheck
                pkgs.util-linux
              ];
            }
            ''
              bash -n \
                ${./scripts/nixos-clean-switch} \
                ${./scripts/nixos-boot-clean} \
                ${./scripts/nixos-generation-snapshot} \
                ${./tests/lifecycle-scripts/run-tests}

              shellcheck \
                ${./scripts/nixos-clean-switch} \
                ${./scripts/nixos-boot-clean} \
                ${./scripts/nixos-generation-snapshot} \
                ${./tests/lifecycle-scripts/run-tests}

              export LIFECYCLE_CLEAN_SWITCH=${./scripts/nixos-clean-switch}
              export LIFECYCLE_BOOT_CLEAN=${./scripts/nixos-boot-clean}
              export LIFECYCLE_GENERATION_SNAPSHOT=${./scripts/nixos-generation-snapshot}
              export LIFECYCLE_VALID_SYSTEM_A=${pkgs.bash}
              export LIFECYCLE_VALID_SYSTEM_B=${pkgs.jq}
              bash ${./tests/lifecycle-scripts/run-tests}

              touch "$out"
            '';
      };

      nixosConfigurations.thinkbook = thinkbook;
    };
}
