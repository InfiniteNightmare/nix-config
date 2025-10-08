{ pkgs, ... }:
{
  programs = {

    vscode = {
      enable = true;
      package = (pkgs.vscode.override { commandLineArgs = [ "--enable-wayland-ime" ]; });
      profiles.default = {
        extensions = with pkgs.vscode-extensions; [
          bbenoist.nix
          eamodio.gitlens
          jnoortheen.nix-ide
          ms-vscode.hexeditor
          # ms-python.python
          ms-toolsai.jupyter
          ms-vscode-remote.remote-ssh
          mkhl.direnv
        ];
        userSettings = {
          "editor.fontSize" = 16;
          "editor.fontFamily" = "FiraCode Nerd Font";
          "files.autoSave" = "afterDelay";
          "git.autofetch" = true;
          "nix.formatterPath" = "${pkgs.nixfmt-rfc-style}/bin/nixfmt";
        };
      };
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
            formatter.command = "${pkgs.nixfmt-rfc-style}/bin/nixfmt";
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
    };
  };
}
