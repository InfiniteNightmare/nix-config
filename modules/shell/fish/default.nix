{ ... }:
{
  # Fish shell configuration separated from the generic shell module.
  # 主要内容：
  # 1. 启用 fish
  # 2. 代理环境变量
  # 3. 启动时条件运行 fastfetch
  # 4. 常用别名

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
        set -gx http_proxy  http://10.214.131.20:7890
        set -gx https_proxy http://10.214.131.20:7890
        set -gx no_proxy localhost,127.0.0.1,::1
        set -gx NO_PROXY $no_proxy
        echo "[proxy] enabled -> $http_proxy"
      end

      function __proxy_off --description 'Disable proxy'
        set -e http_proxy
        set -e https_proxy
        set -e no_proxy
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

      # 如果本地端口开放则自动启用
      if command -q nc
        if nc -z 10.214.131.20 7890 >/dev/null 2>&1
          if not set -q http_proxy
            __proxy_on
          end
        end
      end

      # 定义 abbreviations (输入时自动展开)
      abbr -a gs 'git status'
      abbr -a gl 'git pull'
      abbr -a gp 'git push'
      abbr -a gco 'git checkout'
      abbr -a ll 'eza -al --git'
      abbr -a la 'eza -a'
      abbr -a v 'hx'

      # Starship 由 Home Manager 自动注入，无需手动 init
    '';
  };

  # conf.d 脚本：fastfetch 只显示一次（与主 init 解耦）
  home.file.".config/fish/conf.d/fastfetch.fish".text = ''
    if status is-interactive
      if test "$TERM" != "dumb"; and type -q fastfetch
        if not set -q __fastfetch_shown
          fastfetch
          set -g __fastfetch_shown 1
        end
      end
    end
  '';

  # 如果希望在此模块强制确保 fastfetch 存在（而不是在上游 default.nix 中），可取消注释：
  # home.packages = [ pkgs.fastfetch ];
}
