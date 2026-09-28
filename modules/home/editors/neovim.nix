{
  inputs,
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    clang-tools # clangd LSP + clang-format
    nixfmt
    neovide
  ];

  # 盖掉 neovim 包自带的 Terminal=true 启动项，入口交给 neovide
  xdg.desktopEntries.nvim = {
    name = "Neovim";
    noDisplay = true;
  };

  programs.nixvim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    # 与 flake 其余部分统一使用同一份 nixpkgs（input 已 follows）
    nixpkgs.source = inputs.nixpkgs;

    globals = {
      mapleader = " ";
      maplocalleader = " ";
    };

    opts = {
      number = true;
      relativenumber = true;
      mouse = "a"; # 点击定位、拖拽选择、滚轮、拖分割线
      undofile = true;
      ignorecase = true;
      smartcase = true;
      incsearch = true;
      hlsearch = true;
      expandtab = true;
      shiftwidth = 2;
      tabstop = 2;
      softtabstop = 2;
      smartindent = true;
      wrap = true; # 显示换行（改用 gj/gk 或上下键在视觉行间移动）
      linebreak = true; # 在单词边界断行，避免词中间截断
      breakindent = true; # 换行续行保持缩进
      showbreak = "↪ ";
      scrolloff = 8;
      sidescrolloff = 8;
      signcolumn = "yes";
      updatetime = 250;
      timeoutlen = 400;
      termguicolors = true;
      cursorline = true;
      splitright = true;
      splitbelow = true;
      confirm = true;
      # yank/paste 与系统剪贴板互通（wl-clipboard）
      clipboard = "unnamedplus";
      completeopt = [
        "menu"
        "menuone"
        "noselect"
      ];
    };

    diagnostic.settings = {
      virtual_text = {
        prefix = "●";
        spacing = 2;
      };
      severity_sort = true;
      float.border = "rounded";
    };

    keymaps = [
      {
        key = "<Esc><Esc>";
        action = ":nohlsearch<CR>";
      }
      {
        key = "<S-h>";
        action = ":bprevious<CR>";
      }
      {
        key = "<S-l>";
        action = ":bnext<CR>";
      }
      # wrap 开启后 j/k 跟随视觉行（LazyVim 同款 expr 映射，带计数时按逻辑行）
      {
        key = "j";
        action = "v:count == 0 ? 'gj' : 'j'";
        mode = [
          "n"
          "x"
        ];
        options = {
          expr = true;
          silent = true;
          desc = "Down (visual line, count = logical lines)";
        };
      }
      {
        key = "k";
        action = "v:count == 0 ? 'gk' : 'k'";
        mode = [
          "n"
          "x"
        ];
        options = {
          expr = true;
          silent = true;
          desc = "Up (visual line, count = logical lines)";
        };
      }
      {
        key = "<leader>e";
        action = ":Neotree toggle<CR>";
      }
      {
        key = "<leader>xx";
        action = ":Trouble diagnostics toggle<CR>";
      }
      {
        key = "<leader>cf";
        action.__raw = "function() require('conform').format({ async = true, lsp_fallback = true }) end";
      }
    ];

    autoCmd = [
      # 保存前去行尾空白（最终换行由 fixendofline 默认保证）
      {
        event = [ "BufWritePre" ];
        callback.__raw = ''
          function()
            local view = vim.fn.winsaveview()
            vim.cmd([[keeppatterns %s/\s\+$//e]])
            vim.fn.winrestview(view)
          end
        '';
      }
    ];

    plugins = {
      lsp = {
        enable = true;
        servers = {
          nixd = {
            enable = true;
            settings.nixd.formatting.command = "nixfmt";
          };
          clangd.enable = true;
        };
        keymaps = {
          lspBuf = {
            gd = "definition";
            K = "hover";
            gr = "references";
            "<leader>rn" = "rename";
            "<leader>ca" = "code_action";
          };
          extra = [
            {
              key = "]d";
              action.__raw = "function() vim.diagnostic.jump({ count = 1 }) end";
            }
            {
              key = "[d";
              action.__raw = "function() vim.diagnostic.jump({ count = -1 }) end";
            }
          ];
        };
      };

      treesitter = {
        enable = true;
        nixGrammars = true; # 语法由 nixpkgs 预编译，禁止运行时安装
        settings = {
          highlight.enable = true;
          indent.enable = true;
        };
      };

      cmp = {
        enable = true;
        autoEnableSources = true;
        settings = {
          # nvim 内置 snippet 引擎，免装 luasnip
          snippet.expand = "function(args) vim.snippet.expand(args.body) end";
          mapping = {
            "<C-Space>" = "cmp.mapping.complete()";
            "<CR>" = "cmp.mapping.confirm({ select = true })";
            "<Tab>" =
              "cmp.mapping(function(fallback) if cmp.visible() then cmp.select_next_item() elseif vim.snippet.active({ direction = 1 }) then vim.snippet.jump(1) else fallback() end end, { 'i', 's' })";
            "<S-Tab>" =
              "cmp.mapping(function(fallback) if cmp.visible() then cmp.select_prev_item() elseif vim.snippet.active({ direction = -1 }) then vim.snippet.jump(-1) else fallback() end end, { 'i', 's' })";
          };
          sources = [
            { name = "nvim_lsp"; }
            { name = "path"; }
            { name = "buffer"; }
          ];
        };
      };

      telescope = {
        enable = true;
        # fzf 同款排序算法的 C 实现，加载后自动接管默认排序器
        extensions."fzf-native".enable = true;
        # 插入模式 Esc 直接关闭浮窗；值须为 telescope 动作名（actions.close）
        settings.defaults.mappings.i = {
          "<Esc>" = "close";
        };
        keymaps = {
          "<C-p>" = "find_files"; # 与原 fresh 的 Ctrl+P 对齐
          "<leader>ff" = "find_files";
          "<leader>fg" = "live_grep";
          "<leader>fb" = "buffers";
          "<leader>fh" = "help_tags";
          "<leader>fr" = "oldfiles";
        };
      };

      neo-tree = {
        enable = true;
        settings = {
          close_if_last_window = true;
          window.width = 32;
          filesystem.follow_current_file.enabled = true;
        };
      };

      conform-nvim = {
        enable = true;
        settings = {
          formatters_by_ft = {
            nix = [ "nixfmt" ];
            c = [ "clang-format" ];
            cpp = [ "clang-format" ];
          };
          format_on_save = {
            lsp_fallback = true;
            timeout_ms = 500;
          };
        };
      };

      gitsigns = {
        enable = true;
        settings.on_attach.__raw = ''
          function(bufnr)
            local gs = package.loaded.gitsigns
            local function map(lhs, rhs)
              vim.keymap.set("n", lhs, rhs, { buffer = bufnr, silent = true })
            end
            map("]h", function() gs.nav_hunk("next") end)
            map("[h", function() gs.nav_hunk("prev") end)
            map("<leader>hp", gs.preview_hunk)
            map("<leader>hb", function() gs.blame_line({ full = true }) end)
          end
        '';
      };

      lualine.enable = true;
      which-key = {
        enable = true;
        settings.delay = 300;
      };
      nvim-autopairs.enable = true;
      trouble.enable = true;
    };
  };
}
