{ lib, config, ... }:
{
  /*
    Host-specific secrets module for 'thinkbook'.

    This file is imported AFTER the centralized ../../secrets (default.nix),
    so anything defined here can:
      - Add new secrets used only by this host.
      - Override centralized secrets (same attribute name).
      - Append / override age.identityPaths if this host has extra private keys.

    Quick reference:

    1. Add a host-only secret (create and encrypt *.age first):
         echo 'SomeHostOnlyToken' | age -r 'age1PUBLICKEY...' > nix-config/secrets/thinkbook-extra-token.age

       Then uncomment the block below:
         age.secrets.thinkbook-extra-token = {
           file = ../../secrets/thinkbook-extra-token.age;
         };

    2. Override a shared secret (e.g. use a different WebDAV password for this host):
         age.secrets.webdav-password = {
           file = ../../secrets/webdav-password-alt.age;
         };

    3. Add an additional private key (if you generated a per-host key):
         age.identityPaths = lib.mkAfter [
           "/etc/age/thinkbook-key.txt"
         ];

       mkAfter keeps the shared identity paths and appends this one.

    4. Validating presence of a secret (optional):
         assertions = [{
           assertion = builtins.hasAttr "webdav-password" config.age.secrets;
           message = "webdav-password secret not defined (thinkbook)";
         }];

    Remember:
      - Never commit private keys (only *.age encrypted files).
      - If multiple hosts share a secret, encrypt with multiple -r recipients.

    To add a NEW secret flow:
      a. Generate / collect the password/token into a temp file or echo pipeline.
      b. Encrypt with all required public keys -> place under nix-config/secrets/.
      c. Declare here (host-only) or in ../../secrets/default.nix (shared).
      d. nixos-rebuild switch --flake .#thinkbook
  */

  # ---------------------------------------------------------------------------
  # Host-only additional secret examples (UNCOMMENT to use)
  # ---------------------------------------------------------------------------

  # age.secrets.thinkbook-extra-token = {
  #   file = ../../secrets/thinkbook-extra-token.age;
  # };

  # Override shared webdav password (example):
  # age.secrets.webdav-password = {
  #   file = ../../secrets/webdav-password-alt.age;
  # };

  # Append an additional per-host private key if you generated one:
  # age.identityPaths = lib.mkAfter [
  #   "/etc/age/thinkbook-key.txt"
  # ];

  # Optional assertion examples:
  # assertions = [
  #   {
  #     assertion = builtins.hasAttr "webdav-password" config.age.secrets;
  #     message = "webdav-password secret not defined for thinkbook.";
  #   }
  # ];

}
