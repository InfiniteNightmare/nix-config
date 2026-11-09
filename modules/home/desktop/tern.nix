{
  config,
  ...
}:
{
  # Tern reads ~/.config/tern/settings.json; the in-app settings UI writes the
  # same file, so with this symlink in place changes made in-app do not survive
  # a switch — edit here instead.
  xdg.configFile."tern/settings.json".text = builtins.toJSON {
    # The store binary is read-only, so the built-in updater can never work;
    # bumps go through the flake pin (lib/tern.nix).
    auto_update = false;

    theme = "System";
    theme_dark = "dark-tokyo-night";
    theme_light = "light-tokyo-night";

    # folded from the pre-HM in-app settings
    files.auto_save.after_delay = 1000;
    file_tree.open = true;

    # foot runs at alpha 0.95.
    opacity = 95;

    # tmux prefix chords stay out of typed keys; alt+hjkl adds the vim/zellij
    # muscle memory for pane focus without a prefix.
    keymap = "tmux";
    keybinds = {
      "alt+h" = "focus_pane:left";
      "alt+j" = "focus_pane:down";
      "alt+k" = "focus_pane:up";
      "alt+l" = "focus_pane:right";
      "alt+f" = "zoom";
    };

    font_family = config.stylix.fonts.monospace.name;
    code_font = config.stylix.fonts.monospace.name;
    ui_font = config.stylix.fonts.sansSerif.name;
    font_size = config.stylix.fonts.sizes.terminal;

    # Only the guard tern can actually show (needs zenity, see lib/tern.nix).
    confirm_close = "running_programs";
    copy_on_select = true;
  };
}
