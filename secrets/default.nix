{ userName, ... }:
{
  # Paths to local age private keys used for decryption on this machine.
  age.identityPaths = [
    "/home/${userName}/.ssh/id_ed25519"
  ];

  # Shared WebDAV password secret.
  age.secrets.webdav-password = {
    file = ./webdav-password.age;
  };

  # Minimax API Key (Environment File format: KEY=VALUE)
  age.secrets.minimax-env = {
    file = ./minimax-env.age;
  };

}
