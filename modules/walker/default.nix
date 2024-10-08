{
  programs.walker = {
    enable = true;
    runAsService = true;

    config = {
      placeholder = "Search...";
      keep_open = false;
      ignore_mouse = false;
      ssh_host_file = "";
      enable_typeahead = false;
      show_initial_entries = true;
      fullscreen = false;
      scrollbar_policy = "automatic";
      hyprland = {
        context_aware_history = false;
      };
      activation_mode = {
        disabled = false;
        use_f_keys = false;
        use_alt = false;
      };
      search = {
        delay = 0;
        hide_icons = false;
        margin_spinner = 10;
        hide_spinner = false;
      };
      runner = {
        excludes = [ "rm" ];
      };
      clipboard = {
        max_entries = 10;
        image_height = 300;
      };
      align = {
        ignore_exlusive = true;
        width = 400;
        horizontal = "center";
        vertical = "start";
        anchors = {
          top = false;
          left = false;
          bottom = false;
          right = false;
        };
        margins = {
          top = 0;
          bottom = 0;
          end = 0;
          start = 0;
        };
      };
      list = {
        height = 300;
        margin_top = 10;
        always_show = true;
        hide_sub = false;
      };
      orientation = "vertical";
      icons = {
        theme = "";
        hide = false;
        size = 28;
        image_height = 200;
      };
      modules = [
        # {
        #   name = "runner";
        #   prefix = "";
        # }
        {
          name = "applications";
          prefix = "";
        }
        {
          name = "ssh";
          prefix = "";
          switcher_exclusive = true;
        }
        {
          name = "finder";
          prefix = "";
          switcher_exclusive = true;
        }
        {
          name = "commands";
          prefix = "";
          switcher_exclusive = true;
        }
        {
          name = "websearch";
          prefix = "?";
        }
        {
          name = "switcher";
          prefix = "/";
        }
      ];
    };

    style = builtins.readFile ./style.css;
  };
}
