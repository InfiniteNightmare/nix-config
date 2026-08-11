# Agent Operational Guide (AGENTS.md)

This repository contains a **NixOS Flake configuration** with Home Manager. Agents operating here must adhere to strict Nix best practices, safety protocols regarding secrets, and the specific structural conventions of this flake.

## 1. Build, Lint, and Verify

Since this is a system configuration repo, "tests" are primarily build checks and linting.

### Build Commands
*   **Build System (Dry Run):** To verify a configuration compiles without applying it:
    ```bash
    nix build .#nixosConfigurations.thinkbook.config.system.build.toplevel
    ```
    *Replace `thinkbook` with the relevant hostname if working on a different host.*

*   **Apply Configuration:** (Only if explicitly requested by user)
    ```bash
    sudo nixos-rebuild switch --flake .#thinkbook
    ```

*   **Check Flake Integrity:**
    ```bash
    nix flake check
    ```

### Linting & Formatting
*   **Format Code:** This project enforces `nixfmt`. Always run this on modified files.
    ```bash
    nix fmt
    ```
*   **Syntax Check:**
    ```bash
    nix-instantiate --parse path/to/file.nix
    ```

## 2. Project Structure

*   **`flake.nix`**: The entry point. Defines inputs (nixpkgs, home-manager, etc.) and outputs (nixosConfigurations).
*   **`hosts/`**: Contains machine-specific configurations.
    *   `hosts/<hostname>/default.nix`: The main configuration file for a specific machine.
    *   `hosts/<hostname>/hardware-configuration.nix`: Hardware scan (do not edit manually usually).
*   **`modules/nixos/`**: reusable system-level NixOS modules.
*   **`modules/home/`**: Home Manager modules grouped by user-facing feature.
*   **`lib/`**: shared Nix values that are not modules themselves.
    *   Prefer creating new logic in the appropriate module tree and importing it in `hosts/` rather than writing inline config in `hosts/`.
*   **`secrets/`**: Encrypted secrets managed by `agenix`.

## 3. Code Style & Conventions

### General Nix Style
*   **Indentation:** 2 spaces. No tabs.
*   **Formatting:** Must pass `nix fmt`.
*   **Naming:**
    *   Filenames: `kebab-case.nix` (e.g., `windows-fonts.nix`).
    *   Attributes/Variables: `camelCase` (e.g., `autoMount`, `sshKeyFile`).
*   **Comments:** Use `#` for single-line comments. Document *why*, not *what*.

### Imports
*   Always group imports at the top of the file.
*   Use relative paths for local modules: `imports = [ ./module.nix ../../modules/general ];`
*   Use `inputs.` for flake inputs.

### Functions & Arguments
*   Standard module arguments: `{ config, pkgs, lib, inputs, ... }:`
*   Use `inherit (lib) optionName;` for cleaner lookups if used frequently.

### Secrets Handling (CRITICAL)
*   **Tool:** `agenix` is used for secret management.
*   **Rule:** **NEVER** put passwords, API keys, or private tokens directly in `.nix` files.
*   **Reference:** Refer to secrets via `config.age.secrets.<name>.path`.

## 4. Development Workflow for Agents

1.  **Explore First:** Use `ls -R` or `find` to understand where files are located. Do not guess paths.
2.  **Read Context:** Read `flake.nix` to understand available inputs and overlays before adding new ones.
3.  **Modularize:** If adding a complex feature (e.g., a new service), create a new file in `modules/` and import it, rather than clogging up `hosts/thinkbook/default.nix`.
4.  **No Reverts:** Do not revert changes unless explicitly instructed.
5.  **State Version:** **NEVER** change `system.stateVersion` or `home.stateVersion` unless you are performing a major system upgrade and understand the consequences.

## 5. Specific Configuration Notes
*   **Shell:** The user uses `fish`. Ensure shell aliases/init scripts are compatible or configured via `programs.fish`.
*   **Window Manager:** `niri` (Wayland) is the primary environment.
*   **Editor:** `helix` (`hx`) is the default editor variable, but VS Code and Neovim are also present.
