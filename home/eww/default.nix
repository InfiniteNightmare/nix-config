{ config, pkgs, ... }: {
  # 递归将某个文件夹中的文件，链接到 Home 目录下的指定位置
  home.file.".config/eww" = {
    source = ./config;
    recursive = true; # 递归整个文件夹
  };

  # 直接以 text 的方式，在 nix 配置文件中硬编码文件内容
  # home.file.".xxx".text = ''
  #     xxx
  # '';

}
