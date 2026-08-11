{ userName, ... }:

{
  imports = [
    ./development.nix
    ./desktop
    ./fcitx5.nix
    ./latex.nix
    ./llm-agents.nix
    ./media
    ./proxy
    ./shell
    ./theme.nix
    ./trash.nix
    ./xdg
  ];

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
