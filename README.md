# NixOS configuration

Personal NixOS and Home Manager configuration for the ThinkBook laptop. The
flake output is named `thinkbook`; the installed system hostname is `nixos`.

## Verify and apply

Run checks from the repository root:

```sh
nix flake check
nix build .#nixosConfigurations.thinkbook.config.system.build.toplevel
```

Apply a verified configuration with the repository's cleanup wrapper:

```sh
sudo nixos-clean-switch
```

The wrapper validates the flake, switches to `.#thinkbook`, and trims old boot
artifacts and system generations while preserving rollback and the booted
generation.

## Layout

- `flake.nix` defines the `thinkbook` NixOS configuration.
- `hosts/thinkbook/` contains hardware- and host-specific settings.
- `modules/nixos/` contains reusable system-level NixOS modules.
- `modules/home/` contains Home Manager modules, grouped by user-facing feature.
- `lib/` contains shared Nix helpers and values that are not modules themselves.
- `secrets/` contains only age-encrypted data; plaintext credentials do not
  belong in this repository.
- `scripts/` contains the cleanup helpers packaged by
  `modules/nixos/boot-cleanup.nix`.

Home Manager secrets are decrypted after the user's home directory is mounted.
The system WebDAV automount instead decrypts its encrypted password on demand,
after `/home` is available.

All `.nix` files below `modules/nixos/` and `modules/home/` are discovered
automatically through `lib/module-files.nix`. Keep pure helper expressions in
`lib/`; a path component beginning with `_` is excluded from discovery.
