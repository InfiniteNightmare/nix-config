-- Static part of yazi's global init.lua; the plugin setup loop is prepended
-- by yazi.nix so new plugins under plugins/ wire themselves automatically.
function Linemode:size_and_mtime()
	local time = math.floor(self._file.cha.mtime or 0)
	if time == 0 then
		time = ""
	elseif os.date("%Y", time) == os.date("%Y") then
		time = os.date("%b %d %H:%M", time)
	else
		time = os.date("%b %d %Y", time)
	end
	-- size() is nil for dirs (yazi only computes them with sort_by = "size");
	-- omit the column instead of showing a placeholder.
	local size = self._file:size()
	local parts = {}
	if size then
		parts[#parts + 1] = ya.readable_size(size)
	end
	if time ~= "" then
		parts[#parts + 1] = time
	end
	return table.concat(parts, " ")
end
