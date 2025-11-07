{ pkgs, ... }:

{
  home.file.".config/fcitx5/profile" = {
    source = ./profile;
    # every time fcitx5 switch input method, it will modify ~/.config/fcitx5/profile,
    # so we need to force replace it in every rebuild to avoid file conflict.
    force = true;
  };
  home.file.".config/fcitx5/classicui.conf".source = ./classicui.conf;
  home.file.".config/fcitx5/xim.conf" = {
    source = ./xim.conf;
    force = true;
  };
  home.file.".config/fcitx5/conf/pinyin.conf" = {
    source = ./pinyin.conf;
    force = true;
  };

  # = {
  #   "fcitx5/profile" = {
  #     source = ./profile;
  #     # every time fcitx5 switch input method, it will modify ~/.config/fcitx5/profile,
  #     # so we need to force replace it in every rebuild to avoid file conflict.
  #     force = true;
  #   };
  #   # "fcitx5/conf/classicui.conf".source = ./classicui.conf;
  #   # "fcitx5/conf/xim.conf" = {
  #   #   source = ./xim.conf;
  #   #   force = true;
  #   # };
  # };

  # xdg.dataFile = {
  #   "fcitx5/themes" = {
  #     source = ./themes;
  #     recursive = true;
  #   };
  # };

  i18n.inputMethod = {
    type = "fcitx5";
    enable = true;
    fcitx5.waylandFrontend = true;
    fcitx5.addons = with pkgs; [
      # for flypy chinese input method
      fcitx5-rime
      # needed enable rime using configtool after installed
      qt6Packages.fcitx5-configtool
      qt6Packages.fcitx5-chinese-addons
      # fcitx5-mozc    # japanese input method
      fcitx5-gtk # gtk im module
    ];
  };
}
