{ pkgs, lib, ... }:
{
  programs = {

    zed-editor = {
      enable = true;
      extensions = [
        "nix"
        "toml"
        "mcp-server-context7"
        "mcp-server-sequential-thinking"
      ];
      userSettings = {
        # Autosave
        autosave = {
          after_delay = {
            milliseconds = 500;
          };
        };

        # Agent configuration
        agent = {
          always_allow_tool_actions = true;
          default_model = {
            provider = "copilot_chat";
            model = "claude-sonnet-4.5";
          };
          model_parameters = [ ];
        };

        # Context servers (MCP)
        context_servers = {
          mcp-server-context7 = {
            source = "extension";
            enabled = true;
            settings = {
              context7_api_key = "ctx7sk-822d6ba1-f246-4b17-9b7a-4de90cfc74bc";
            };
          };
        };

        # Helix mode
        helix_mode = true;

        # Font settings
        buffer_font_family = "FiraCode Nerd Font Mono";
        ui_font_size = 16.0;

        # Telemetry
        telemetry = {
          diagnostics = false;
          metrics = false;
        };

        # LSP
        lsp = {
          nix = {
            binary = {
              path = "${lib.getExe pkgs.nil}";
            };
          };
        };

        # Terminal
        terminal = {
          shell = {
            program = "${lib.getExe pkgs.fish}";
          };
          font_family = "FiraCode Nerd Font Mono";
          font_size = 15.0;
        };
      };
    };

    vscode = {
      enable = false;
      # package = (pkgs.vscode.override { commandLineArgs = [ "--enable-wayland-ime" ]; });
      /*
        profiles.default = {
          extensions = with pkgs.vscode-extensions; [
            bbenoist.nix
            eamodio.gitlens
            jnoortheen.nix-ide
            MS-CEINTL.vscode-language-pack-zh-hans
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
      */
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
