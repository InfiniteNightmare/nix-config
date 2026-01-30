{ lib, ... }:
let
  charname = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFNAmYWAguhT73kqYCOq/eba6QpYjCdFbRz9pCix8Vdl haobosun@zju.edu.cn";
  users = [ charname ];
in
{
  # Paths to local age private keys used for decryption on this machine.
  age.identityPaths = [
    "/home/charname/.ssh/id_ed25519"
  ];

  # Shared WebDAV password secret.
  age.secrets.webdav-password = {
    file = ./webdav-password.age;
  };


}
