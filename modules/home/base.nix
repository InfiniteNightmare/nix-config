{ userName, ... }:

{
  home = {
    username = userName;
    homeDirectory = "/home/${userName}";

    # Do not change this during routine updates; migration history needs separate review.
    stateVersion = "26.05";
    enableNixpkgsReleaseCheck = false;
  };

  programs.home-manager.enable = true;

  services.syncthing.enable = true;
}
