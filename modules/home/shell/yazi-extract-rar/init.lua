-- Register the extract-rar remote at startup so the "extract-rar" opener
-- (see yazi.toml) can dispatch to this plugin. User plugins are not
-- auto-setup like presets, so this file is wired via programs.yazi.initLua.
require("extract-rar"):setup()
