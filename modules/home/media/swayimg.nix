{
  config,
  pkgs,
  ...
}:

let
  # init.lua runs on top of swayimg's built-in defaults, so it only carries
  # overrides. Colors mustache-render from the stylix palette; unrendered
  # placeholders would silently ship a broken config, so fail loudly instead.
  # Replace with stylix targets.swayimg once nix-community/stylix#2064 lands.
  initLua = pkgs.runCommand "init.lua" { } ''
    cat "${
      config.lib.stylix.colors {
        template = ''
          -- Palette from the stylix scheme (ARGB, fully opaque)

          -- Load the rest of the directory so wheel/g/G can flip through
          -- images opened from a file manager (default list is one file)
          swayimg.imagelist.adjacent = true

          -- Info overlay stays hidden until t
          swayimg.text.visible = false

          -- Viewer: vim keys; pan step larger than the built-in arrows' 10px
          local step = 50
          local function pan(dx, dy)
            local pos = swayimg.viewer.get_position()
            swayimg.viewer.set_abs_position(pos.x + dx, pos.y + dy)
          end

          swayimg.viewer.on_key("h", function() pan(step, 0) end)
          swayimg.viewer.on_key("l", function() pan(-step, 0) end)
          swayimg.viewer.on_key("j", function() pan(0, -step) end)
          swayimg.viewer.on_key("k", function() pan(0, step) end)

          swayimg.viewer.on_key("n", function() swayimg.viewer.open("next") end)
          swayimg.viewer.on_key("p", function() swayimg.viewer.open("prev") end)
          swayimg.viewer.on_key("space", function() swayimg.viewer.open("next") end)
          swayimg.viewer.on_key("g", function() swayimg.viewer.open("first") end)
          swayimg.viewer.on_key("Shift+g", function() swayimg.viewer.open("last") end)

          swayimg.viewer.on_key("r", function() swayimg.viewer.rotate(90) end)
          swayimg.viewer.on_key("Shift+r", function() swayimg.viewer.rotate(270) end)

          -- Viewer: scroll wheel flips images (XnView/FastStone style);
          -- Ctrl+wheel or +/- zooms, drag and h/j/k/l pan
          swayimg.viewer.on_mouse("ScrollUp", function()
            swayimg.viewer.open("prev")
          end)
          swayimg.viewer.on_mouse("ScrollDown", function()
            swayimg.viewer.open("next")
          end)

          -- Ctrl+r pulls the subdirectories of the current folder into the
          -- list; imagelist.add dedupes by path, so no entries are doubled
          local expandedDirs = {}
          local function expandRecursive(img)
            if not img then return end
            local dir = img.path:match("^(.*/)[^/]+$") or "./"
            if expandedDirs[dir] then return end
            expandedDirs[dir] = true
            swayimg.imagelist.recursive = true
            swayimg.imagelist.add(dir)
            swayimg.text.status = "子目录已加入列表"
          end
          swayimg.viewer.on_key("Ctrl+r", function()
            expandRecursive(swayimg.viewer.get_image())
          end)
          swayimg.gallery.on_key("Ctrl+r", function()
            expandRecursive(swayimg.gallery.get_image())
          end)

          -- F1/? shows keybindings on the text overlay; the text scheme is
          -- write-only, so the info layout is kept here to restore on close
          local viewerInfo = {
            topleft = {
              "File:\t{name}",
              "Format:\t{format}",
              "File size:\t{sizehr}",
              "File time:\t{time}",
              "EXIF date:\t{meta.Exif.Photo.DateTimeOriginal}",
              "EXIF camera:\t{meta.Exif.Image.Model}",
            },
            topright = {
              "Image:\t{list.index} of {list.total}",
              "Frame:\t{frame.index} of {frame.total}",
              "Size:\t{frame.width}x{frame.height}",
            },
            bottomleft = { "Scale:\t{scale}" },
          }
          local galleryInfo = {
            topleft = { "File:\t{name}" },
            topright = { "{list.index} of {list.total}" },
          }
          local helpShown = { viewer = false, gallery = false }
          local function toggleHelp(mode, help, info)
            helpShown[mode] = not helpShown[mode]
            swayimg[mode].text = helpShown[mode] and help or info
            swayimg.text.visible = helpShown[mode]
          end
          swayimg.viewer.on_key({ "F1", "question" }, function()
            toggleHelp("viewer", {
              topleft = {
                "swayimg 快捷键:",
                "滚轮: 上一张/下一张    Ctrl+滚轮: 缩放",
                "+/-: 缩放    h/j/k/l 或拖拽: 平移",
                "n/p/space: 上一张/下一张    g/G: 首张/末张",
                "Enter: 画廊模式    r/R: 顺时针/逆时针旋转",
                "f: 全屏    t: 信息层    Ctrl+r: 加入子目录",
                "F1: 关闭帮助    Esc: 退出",
              },
            }, viewerInfo)
          end)
          swayimg.gallery.on_key({ "F1", "question" }, function()
            toggleHelp("gallery", {
              topleft = {
                "swayimg 画廊快捷键:",
                "h/j/k/l 或滚轮: 移动选择    Enter: 查看图片",
                "+/-: 缩略图大小    g/G: 首张/末张",
                "f: 全屏    t: 信息层    Ctrl+r: 加入子目录",
                "F1: 关闭帮助    Esc: 退出",
              },
            }, galleryInfo)
          end)

          -- Gallery: same cursor language
          swayimg.gallery.on_key("h", function() swayimg.gallery.select("left") end)
          swayimg.gallery.on_key("j", function() swayimg.gallery.select("down") end)
          swayimg.gallery.on_key("k", function() swayimg.gallery.select("up") end)
          swayimg.gallery.on_key("l", function() swayimg.gallery.select("right") end)
          swayimg.gallery.on_key("g", function() swayimg.gallery.select("first") end)
          swayimg.gallery.on_key("Shift+g", function() swayimg.gallery.select("last") end)

          -- Slideshow: manual override in the same direction
          swayimg.slideshow.on_key("n", function() swayimg.slideshow.open("next") end)
          swayimg.slideshow.on_key("p", function() swayimg.slideshow.open("prev") end)

          swayimg.viewer.set_window_background(0xff{{base00-hex}})
          swayimg.gallery.window_color = 0xff{{base00-hex}}
          swayimg.gallery.unselected_color = 0xff{{base01-hex}}
          swayimg.gallery.selected_color = 0xff{{base02-hex}}
          swayimg.gallery.border_color = 0xff{{base05-hex}}
          swayimg.text.color = 0xff{{base05-hex}}
          -- Single font face, no glyph fallback in swayimg (missing glyphs
          -- render as '?') — needs a CJK-capable font for the help panel
          swayimg.text.font = "Noto Sans Mono CJK SC"
        '';
        extension = ".lua";
      }
    }" > "$out"
    if grep -q '{{' "$out"; then
      echo "stylix palette placeholders did not render for swayimg; recheck modules/home/media/swayimg.nix" >&2
      exit 1
    fi
  '';
in
{
  home.packages = [ pkgs.swayimg ];

  home.file.".config/swayimg/init.lua".source = initLua;
}
