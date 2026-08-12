# NixOS configuration

Personal NixOS and Home Manager configuration for the ThinkBook laptop. The
flake output is named `thinkbook`; the installed system hostname is `nixos`.

## Verify and apply

Run checks from the repository root:

```sh
nix flake check
nix build --no-link .#nixosConfigurations.thinkbook.config.system.build.toplevel
```

Apply a verified configuration with the repository's cleanup wrapper:

```sh
sudo nixos-clean-switch
```

The wrapper builds `.#thinkbook` once without creating a `result` link, switches
to that pre-built store path, and trims old boot artifacts and system
generations while preserving rollback and the booted generation.

Each NixOS generation gets one immutable Btrfs checkpoint containing read-only
root and home snapshots in the top-level `@nixos-snapshots` subvolume. The
wrapper seeds an older generation before first leaving it and records each new
generation immediately after a successful switch. Managed sets use the exact
system generation and store hash as their identity; a set is removed only after
its matching system generation has been removed. Use `nixos-clean-switch` as
the switch entry point so the two lifecycles remain paired. `/data` is
intentionally excluded because its data lifecycle is independent from NixOS
system generations. It is checked by the monthly Btrfs scrub, but no automated
off-device backup is configured.

A checkpoint represents the mutable state when that generation was first
adopted; it is not refreshed on later departures. This keeps the restore point
immutable even if a generation is selected again without restoring its data.
Changing `filesystemMount`/`storageSubvolume` or disabling generation
checkpoints does not migrate the old managed namespace; prune or migrate it
explicitly before that change.

Choosing an older generation in GRUB rolls back the NixOS system closure only.
Restoring mutable root or home data from a paired Btrfs set remains a separate,
offline recovery operation; the wrapper never overwrites a live filesystem.
The snapshots remain on the same disk and are recovery checkpoints, not
backups. Root and home are captured moments apart rather than as a
cross-subvolume transaction, so applications that require transactional
consistency must be stopped before creating a checkpoint.

After first enabling this mechanism, establish the initial managed checkpoint:

```sh
sudo nixos-generation-snapshot capture-current
```

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
