{ lib }:

directory:
lib.filter (
  path:
  let
    pathString = toString path;
  in
  lib.hasSuffix ".nix" pathString && !(lib.hasInfix "/_" pathString)
) (lib.filesystem.listFilesRecursive directory)
