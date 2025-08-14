{ conifg, pkgs, ... }:
let
  google-fonts = (
    pkgs.google-fonts.override {
      fonts = [
        # Sans
        "Gabarito"
        "Lexend"
        # Serif
        "Chakra Petch"
        "Crimson Text"
      ];
    }
  );
in
{
  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.supportedLocales = [
    "all"
    #   "C.UTF-8/UTF-8"
    #   "en_US.UTF-8/UTF-8"
    #   "ja_JP.UTF-8/UTF-8"
    #   "zh_CN.UTF-8/UTF-8"
  ];

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "zh_CN.UTF-8";
    LC_IDENTIFICATION = "zh_CN.UTF-8";
    LC_MEASUREMENT = "zh_CN.UTF-8";
    LC_MONETARY = "zh_CN.UTF-8";
    LC_NAME = "zh_CN.UTF-8";
    LC_NUMERIC = "zh_CN.UTF-8";
    LC_PAPER = "zh_CN.UTF-8";
    LC_TELEPHONE = "zh_CN.UTF-8";
    LC_TIME = "zh_CN.UTF-8";
  };

  fonts = {
    packages = with pkgs; [
      material-symbols
      material-icons
      nerd-fonts.fira-code
      nerd-fonts.ubuntu
      nerd-fonts.ubuntu-mono
      nerd-fonts.fantasque-sans-mono
      nerd-fonts.jetbrains-mono
      nerd-fonts.mononoki
      nerd-fonts.space-mono
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      noto-fonts-emoji
      source-han-sans
      source-han-serif
      google-fonts
    ];
    fontDir.enable = true;
    fontconfig = {
      antialias = true;
      hinting.enable = true;
      defaultFonts = {
        emoji = [ "Noto Color Emoji" ];
        monospace = [ "FiraCode Nerd Font" ];
        sansSerif = [
          "Noto Sans CJK SC"
          "Source Han Sans SC"
        ];
        serif = [
          "Noto Serif CJK SC"
          "Source Han Serif SC"
        ];
      };
    };
  };
}
