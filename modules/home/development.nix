{ pkgs, ... }:
{
  home.packages = with pkgs; [
    gnumake
    nix-output-monitor
    hugo
    gh
    vscode
    uv
    devbox
    neovide
    nixd
  ];

  programs = {
    git = {
      enable = true;
      settings = {
        user.name = "InfiniteNightmare";
        user.email = "742851870@qq.com";
      };
    };

    direnv = {
      enable = true;
      enableBashIntegration = true;
      nix-direnv.enable = true;
    };

    zed-editor = {
      enable = true;
    };

    helix = {
      enable = true;
      settings = {
        # theme = "autumn_night_transparent";
        editor.cursor-shape = {
          normal = "block";
          insert = "bar";
          select = "underline";
        };
      };
      languages = {
        language-server = {
          clangd = {
            command = "${pkgs.clang-tools}/bin/clangd";
          };
        };
        language = [
          {
            name = "nix";
            auto-format = true;
            language-servers = [ "nixd" ];
            formatter.command = "${pkgs.nixfmt}/bin/nixfmt";
          }
          {
            name = "cpp";
            auto-format = true;
            roots = [
              ".git"
              "CMakeLists.txt"
            ];
            workspace-lsp-roots = [
              ".clangd"
              "compile_commands.json"
            ];
            language-servers = [ "clangd" ];
            formatter.command = "${pkgs.clang-tools}/bin/clang-format";
            debugger = {
              name = "lldb-dap";
              command = "${pkgs.lldb}/bin/lldb-dap";
              transport = "stdio";
              templates = [
                {
                  name = "binary";
                  request = "launch";
                  completion = [
                    {
                      name = "binary";
                      completion = "filename";
                    }
                  ];
                  args = {
                    program = "{0}";
                  };
                }
              ];
            };
          }
        ];
      };
      # themes = {
      # autumn_night_transparent = {
      # "inherits" = "autumn_night";
      # "ui.background" = { };
      # };
      # };
    };

    neovim = {
      enable = true;
      withRuby = false;
      withPython3 = false;
    };
  };
}
