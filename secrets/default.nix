{ lib, ... }:
{
  /*
    Centralized age/agenix (ragenix) secrets declaration.

    Usage summary:

    1. Generate an age key (once per environment / host set):
         sudo install -d -m 700 /etc/age
         sudo age-keygen -o /etc/age/agenix-key.txt
       The file contains:
         # public key: age1xxxxxxxx...
       Keep /etc/age/agenix-key.txt OUT of version control.

    2. Encrypt your WebDAV password into webdav-password.age (current encrypted file name mapped to secret name webdav-password):
         echo 'YourPlainPassword' | age -r 'age1xxxxxxxx...' > nix-config/secrets/webdav-password.age
        (Or use `ragenix -e nix-config/secrets/webdav-password.age` interactively.)

    3. This file (secrets.nix) is imported by each host that needs the secret.
       Example (in a host config):
         imports = [
           ../../secrets
           # other modules...
         ];

    4. The module `modules/filesystems/webdav.nix` references:
         filesystems.webdav.mounts = [
           {
             url = "...";
             mountPoint = "/mnt/fnos";
             username = "webdav_user";
             passwordAgenixSecret = "webdav-password";
             automount = true;
           }
         ];

    5. Rebuild:
         sudo nixos-rebuild switch --flake .#thinkbook

    Adding more secrets:
      - Place additional *.age files alongside this one.
      - Declare them similarly under age.secrets.<name>.
      - Reference via passwordAgenixSecret = "<name>";

    Multiple hosts with different keys:
      - You can include multiple public keys when encrypting (multiple -r options),
        or maintain per-host encrypted files if they must differ.

    Rotation:
      - Re-encrypt the password to the same file path and rebuild.

    Security:
      - Never commit the private key.
      - The decrypted secret is only present on the target system at activation time.
  */

  # Paths to local age private keys used for decryption on this machine.
  # If using different keys per host, you can override / extend this in per-host secrets files.
  age.identityPaths = [
    "/etc/age/agenix-key"
  ];

  # Shared WebDAV password secret.
  # The encrypted file must exist at nix-config/secrets/webdav-password.age relative to repo root.
  age.secrets.webdav-password = {
    file = ./webdav-password.age;

    # Optional overrides (defaults: owner=root group=root mode=0400)
    # owner = "root";
    # group = "root";
    # mode = "0400";
  };

  # Example template for another secret (uncomment & customize):
  # age.secrets.nextcloud-pass = {
  #   file = ./nextcloud-pass.age;
  # };

  # If you ever need to conditionally include a secret only for certain systems,
  # you can use mkIf with some predicate (e.g., hostname), for example:
  # age.secrets.special-token = lib.mkIf (config.networking.hostName == "thinkbook") {
  #   file = ./special-token.age;
  # };

}
