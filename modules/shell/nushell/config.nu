# show_banner (bool): Enable or disable the welcome banner at startup
$env.config.show_banner = false

# zellij
# def start_zellij_in_alacritty [] {
#   if $env.TERM == "alacritty" {
#     if 'ZELLIJ' not-in ($env | columns) {
#       if 'ZELLIJ_AUTO_ATTACH' in ($env | columns) and $env.ZELLIJ_AUTO_ATTACH == 'true' {
#         zellij attach -c
#       } else {
#         zellij
#       }

#       if 'ZELLIJ_AUTO_EXIT' in ($env | columns) and $env.ZELLIJ_AUTO_EXIT == 'true' {
#         exit
#       }
#     }
#   }
# }

# start_zellij_in_alacritty

use ~/.cache/starship/init.nu
fastfetch
# source ~/.config/zoxide.nu

def --env yy [...args] {
	let tmp = (mktemp -t "yazi-cwd.XXXXXX")
	yazi ...$args --cwd-file $tmp
	let cwd = (open $tmp)
	if $cwd != "" and $cwd != $env.PWD {
		cd $cwd
	}
	rm -fp $tmp
}
