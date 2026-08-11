{
  config,
  lib,
  pkgs,
  ...
}:

let
  wallpaper = config.services.wallhavenWallpaper;
in
{
  programs.noctalia = {
    enable = true;
    settings = {
      accessibility.ui_scale = 1.0;

      shell = {
        corner_radius_scale = 1.06;
        font_family = lib.mkDefault "sans-serif";
        lang = "zh-CN";
        time_format = "{:%H:%M}";
        date_format = "%A, %x";
        offline_mode = false;
        telemetry_enabled = false;
        setup_wizard_enabled = false;
        niri_overview_type_to_launch_enabled = false;
        polkit_agent = false;
        password_style = "default";
        settings_show_advanced = true;
        show_location = true;
        app_icon_colorize = false;
        launch_apps_as_systemd_services = false;
        clipboard_enabled = true;
        clipboard_history_max_entries = 80;
        clipboard_confirm_clear_history = true;
        screen_time_enabled = false;
        shared_gl_context = true;
        clipboard_auto_paste = "auto";
        clipboard_image_action_command = "language-tools prepare-ocr-path {path}";

        animation = {
          enabled = true;
          speed = 1.08;
        };

        shadow = {
          direction = "down_right";
          alpha = 0.55;
        };

        panel = {
          transparency_mode = "glass";
          borders = true;
          shadow = true;
          launcher_placement = "floating";
          clipboard_placement = "floating";
          control_center_placement = "attached";
          wallpaper_placement = "attached";
          session_placement = "attached";
          launcher_position = "center";
          clipboard_position = "center";
          open_near_click_control_center = true;
          open_near_click_launcher = false;
          open_near_click_clipboard = false;
          open_near_click_wallpaper = true;
          open_near_click_session = true;
        };

        launcher = {
          categories = true;
          show_icons = true;
          compact = false;
        };

        screen_corners = {
          enabled = false;
          size = 32;
        };

        mpris.blacklist = [ ];

        session.actions = [
          {
            action = "lock";
            enabled = true;
            shortcut = "1";
            variant = "default";
          }
          {
            action = "lock_and_suspend";
            enabled = true;
            shortcut = "2";
            variant = "default";
          }
          {
            action = "logout";
            enabled = true;
            shortcut = "3";
            variant = "default";
          }
          {
            action = "reboot";
            enabled = true;
            shortcut = "4";
            variant = "default";
          }
          {
            action = "shutdown";
            enabled = true;
            shortcut = "5";
            variant = "destructive";
          }
        ];
      };

      backdrop = {
        enabled = true;
        blur_intensity = 0.35;
        tint_intensity = 0.18;
      };

      bar = {
        order = [ "main" ];

        main = {
          enabled = true;
          position = "top";
          auto_hide = false;
          reserve_space = true;
          layer = "top";
          thickness = 36;
          background_opacity = 0.78;
          border = "outline";
          border_width = 0;
          radius = 14;
          margin_ends = 8;
          margin_edge = 6;
          padding = 10;
          widget_spacing = 6;
          shadow = true;
          contact_shadow = false;
          panel_overlap = 1;
          scale = 1.0;
          font_weight = 500;
          start = [
            "control-center"
            "launcher"
            "cpu"
            "ram"
            "active_window"
            "media"
          ];
          center = [ "workspaces" ];
          end = [
            "tray"
            "notifications"
            "clipboard"
            "network"
            "bluetooth"
            "volume"
            "brightness"
            "battery"
            "clock"
            "session"
          ];
          capsule = true;
          capsule_fill = "surface_variant";
          capsule_padding = 7;
          capsule_radius = 10.0;
          capsule_opacity = 0.86;
          capsule_border = "outline";
        };
      };

      widget = {
        control-center = {
          glyph = "noctalia";
          custom_image = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
          custom_image_colorize = false;
          capsule = true;
        };

        launcher = {
          glyph = "search";
          capsule = true;
        };

        cpu = {
          type = "sysmon";
          stat = "cpu_usage";
          visualization = "none";
          show_value = true;
          label_min_width = 34;
          highlight_color = "primary";
          capsule = true;
        };

        ram = {
          type = "sysmon";
          stat = "ram_pct";
          visualization = "none";
          show_value = true;
          label_min_width = 34;
          highlight_color = "secondary";
          capsule = true;
        };

        active_window = {
          min_length = 80;
          max_length = 260;
          icon_size = 14.0;
          title_scroll = "on_hover";
          display = "icon_and_text";
          capsule = false;
        };

        media = {
          min_length = 80;
          max_length = 220;
          art_size = 16.0;
          title_scroll = "on_hover";
          hide_when_no_media = true;
          capsule = true;
        };

        workspaces = {
          style = "regular";
          show_labels = true;
          label_source = "id";
          labels_only_when_occupied = false;
          hide_when_empty = false;
          max_label_chars = 2;
          pill_scale = 0.9;
          focused_color = "primary";
          occupied_color = "secondary";
          empty_color = "secondary";
          capsule = true;
          capsule_radius = 12.0;
        };

        tray = {
          hidden = [ ];
          pinned = [ ];
          match_adjacent_spacing = true;
          drawer = false;
        };

        notifications.hide_when_no_unread = false;

        clipboard = {
          glyph = "clipboard";
          capsule = true;
        };

        network = {
          show_label = false;
          capsule = true;
        };

        bluetooth = {
          show_label = false;
          hide_when_no_connected_device = false;
          capsule = true;
        };

        volume = {
          device = "output";
          show_label = true;
          capsule = true;
        };

        brightness = {
          show_label = true;
          capsule = true;
        };

        battery = {
          display_mode = "glyph";
          show_label = true;
          hide_when_plugged = false;
          hide_when_full = false;
          warning_color = "error";
          capsule = true;
        };

        clock = {
          format = "{:%H:%M}";
          tooltip_format = "{:%A, %Y-%m-%d}";
          font_weight = 600;
          capsule = true;
        };

        session = {
          glyph = "shutdown";
          capsule = true;
        };
      };

      control_center = {
        sidebar = "compact";
        sidebar_section = "compact";
        shortcuts = [
          { type = "wifi"; }
          { type = "bluetooth"; }
          { type = "wallpaper"; }
          { type = "caffeine"; }
          { type = "nightlight"; }
        ];
      };

      dock = {
        enabled = true;
        position = "bottom";
        active_monitor_only = true;
        icon_size = 46;
        main_axis_padding = 14;
        cross_axis_padding = 8;
        item_spacing = 6;
        background_opacity = lib.mkDefault 0.86;
        radius = 16;
        margin_ends = 0;
        margin_edge = 8;
        shadow = true;
        show_running = true;
        auto_hide = true;
        reserve_space = false;
        active_scale = 1.0;
        inactive_scale = 0.85;
        magnification = true;
        magnification_scale = 1.35;
        active_opacity = 1.0;
        inactive_opacity = 0.82;
        show_dots = false;
        show_instance_count = true;
        launcher_position = "none";
        launcher_icon = "grid-dots";
        pinned = [ ];
        monitors = [ ];
      };

      wallpaper = {
        enabled = true;
        fill_mode = "crop";
        fill_color = "#000000";
        transition = [
          "fade"
          "wipe"
          "zoom"
          "honeycomb"
        ];
        transition_duration = 1200;
        edge_smoothness = 0.3;
        transition_on_startup = false;
        inherit (wallpaper) directory;
        directory_light = "";
        directory_dark = "";
        per_monitor_directories = true;

        automation = {
          enabled = true;
          interval_seconds = 900;
          order = "random";
          recursive = true;
        };

        monitor = {
          "eDP-1".directory = wallpaper.directory;
          "DP-1".directory = wallpaper.directory;
          "DP-2".directory = wallpaper.directory;
          "HDMI-A-1".directory = wallpaper.directory;
        };
      };

      theme = {
        mode = lib.mkDefault "dark";
        source = lib.mkDefault "builtin";
        builtin = "Tokyo-Night";
        wallpaper_scheme = "m3-content";
        templates = {
          enable_builtin_templates = true;
          builtin_ids = [ ];
          enable_community_templates = true;
          community_ids = [ ];
        };
      };

      notification = {
        enable_daemon = true;
        show_app_name = true;
        show_actions = true;
        position = "top_right";
        layer = "overlay";
        scale = 1.0;
        background_opacity = lib.mkDefault 0.94;
        offset_x = 18;
        offset_y = 10;
        monitors = [ ];
        collapse_on_dismiss = true;
        blacklist = [ ];
        blacklist_allow_critical = true;
      };

      osd = {
        position = "top_right";
        orientation = "horizontal";
        scale = 1.0;
        background_opacity = lib.mkDefault 0.94;
        offset_x = 18;
        offset_y = 10;
        monitors = [ ];
        kinds = {
          volume = true;
          volume_output = true;
          volume_input = true;
          brightness = true;
          wifi = true;
          bluetooth = true;
          caffeine = true;
          dnd = true;
          lock_keys = true;
          keyboard_layout = true;
        };
      };

      lockscreen = {
        blurred_desktop = false;
        blur_intensity = 0.5;
        tint_intensity = 0.3;
        wallpaper = "";
      };

      desktop_widgets = {
        enabled = false;
        schema_version = 2;
        grid = {
          visible = true;
          cell_size = 16;
          major_interval = 4;
        };
      };

      system.monitor = {
        enabled = true;
        cpu_poll_seconds = 2.0;
        gpu_poll_seconds = 5.0;
        memory_poll_seconds = 2.0;
        network_poll_seconds = 3.0;
        disk_poll_seconds = 10.0;
        cpu_usage_activity_threshold = 80.0;
        cpu_usage_critical_threshold = 90.0;
        cpu_temp_activity_threshold = 80.0;
        cpu_temp_critical_threshold = 90.0;
        ram_pct_activity_threshold = 80.0;
        ram_pct_critical_threshold = 90.0;
      };

      weather = {
        enabled = true;
        effects = true;
        refresh_minutes = 30;
        unit = "metric";
      };

      calendar = {
        enabled = true;
        refresh_minutes = 15;
      };

      audio = {
        enable_overdrive = false;
        enable_sounds = false;
        sound_volume = 0.5;
        volume_change_sound = "";
        notification_sound = "";
      };

      brightness = {
        enable_ddcutil = false;
        ignore_mmids = [ ];
      };

      nightlight = {
        enabled = true;
        force = false;
        temperature_day = 6500;
        temperature_night = 4000;
      };

      location = {
        auto_locate = false;
        address = "Hangzhou, China";
        sunrise = "06:30";
        sunset = "18:30";
      };

      battery.warning_threshold = 20;

      hooks = {
        started = [ ];
        wallpaper_changed = [ ];
        colors_changed = [ ];
        theme_mode_changed = [ ];
        session_locked = [ ];
        session_unlocked = [ ];
        logging_out = [ ];
        rebooting = [ ];
        shutting_down = [ ];
        wifi_enabled = [ ];
        wifi_disabled = [ ];
        bluetooth_enabled = [ ];
        bluetooth_disabled = [ ];
        battery_charging = [ ];
        battery_discharging = [ ];
        battery_plugged = [ ];
        battery_percentage_changed = [ ];
        power_profile_changed = [ ];
      };
    };
  };
}
