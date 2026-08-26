{ config, pkgs, ... }:
let
  proxySettings = import ../../../lib/proxy-settings.nix;
  stylixColors = config.lib.stylix.colors.withHashtag;
  fastfetchLogoColors = {
    "1" = stylixColors.base0D;
    "2" = stylixColors.base0C;
    "3" = stylixColors.base0D;
    "4" = stylixColors.base0C;
    "5" = stylixColors.base0D;
    "6" = stylixColors.base0C;
  };
  fastfetchDisplay = {
    separator = "";
    brightColor = false;
    duration.abbreviation = true;
    key = {
      type = "string";
      width = 9;
    };
    color = {
      title = stylixColors.base0D;
      keys = stylixColors.base0D;
      separator = stylixColors.base03;
      output = stylixColors.base05;
    };
  };
  fastfetchOs = {
    type = "os";
    format = "{name} {version-id}";
  };
  fastfetchKernel = {
    type = "kernel";
    format = "{release}";
  };
  fastfetchMemory = {
    type = "memory";
    format = "{used} / {total}";
  };
  fastfetchBattery = {
    type = "battery";
    key = "Battery";
    format = "{capacity} [{status}]";
  };
in
{
  # Fish shell configuration separated from the generic shell module.
  # 主要内容：
  # 1. 启用 fish
  # 2. 代理环境变量
  # 3. 启动时条件运行 fastfetch
  # 4. 常用别名

  home.packages = with pkgs; [
    eza
  ];

  programs.fastfetch = {
    enable = true;
    settings = {
      # Package counting dominates the default startup time on NixOS, while
      # version probing adds little value to a splash shown in every terminal.
      general.detectVersion = false;
      logo = {
        type = "builtin";
        source = "NixOS";
        padding.right = 1;
        color = fastfetchLogoColors;
      };
      display = fastfetchDisplay;
      modules = [
        "title"
        "separator"
        fastfetchOs
        {
          type = "host";
          format = "{family}";
        }
        fastfetchKernel
        "uptime"
        "shell"
        {
          type = "terminal";
          key = "Term";
        }
        {
          type = "display";
          key = "Display";
          format = "{width}x{height} @ {refresh-rate} Hz";
        }
        "wm"
        {
          type = "cpu";
          format = "{name}";
        }
        {
          type = "gpu";
          format = "{name}";
        }
        fastfetchMemory
        {
          type = "swap";
          format = "{used} / {total}";
        }
        {
          type = "disk";
          key = "Root";
          folders = "/";
          format = "{size-used} / {size-total}";
        }
        {
          type = "disk";
          key = "Data";
          folders = "/data";
          format = "{size-used} / {size-total}";
        }
        {
          type = "localip";
          key = "Network";
        }
        fastfetchBattery
        "colors"
      ];
    };
  };

  programs.fish = {
    enable = true;

    # 一些简单别名，可按需增减
    shellAliases = {
      ll = "eza -al --git";
      la = "eza -a";
      gs = "git status";
      gl = "git pull";
      gp = "git push";
      v = "hx";
    };

    interactiveShellInit = ''
      # 关闭默认欢迎语
      set -g fish_greeting ""

      # 代理控制函数与智能启用
      function __proxy_on --description 'Enable local proxy'
        set -gx http_proxy  ${proxySettings.httpProxy}
        set -gx https_proxy ${proxySettings.httpsProxy}
        set -gx all_proxy   ${proxySettings.allProxy}
        set -gx no_proxy    ${proxySettings.noProxy}

        set -gx HTTP_PROXY $http_proxy
        set -gx HTTPS_PROXY $https_proxy
        set -gx ALL_PROXY $all_proxy
        set -gx NO_PROXY $no_proxy
        echo "[proxy] enabled -> $http_proxy"
      end

      function __proxy_off --description 'Disable proxy'
        set -e http_proxy
        set -e https_proxy
        set -e all_proxy
        set -e no_proxy

        set -e HTTP_PROXY
        set -e HTTPS_PROXY
        set -e ALL_PROXY
        set -e NO_PROXY
        echo "[proxy] disabled"
      end

      function proxy --description 'proxy (on|off|toggle|status)'
        switch "$argv[1]"
          case on
            __proxy_on
          case off
            __proxy_off
          case toggle
            if set -q http_proxy
              __proxy_off
            else
              __proxy_on
            end
          case status
            if set -q http_proxy
              echo "[proxy] ON -> $http_proxy"
            else
              echo "[proxy] OFF"
            end
          case '*'
            echo "usage: proxy (on|off|toggle|status)"
        end
      end

      # Starship 由 Home Manager 自动注入，无需手动 init
    '';
  };

  # conf.d 脚本：每个新交互终端显示 fastfetch（与主 init 解耦）
  home.file.".config/fish/conf.d/fastfetch.fish".text = ''
    if status is-interactive; and isatty stdout; and test "$TERM" != "dumb"; and type -q fastfetch
      command fastfetch
    end
  '';
}
