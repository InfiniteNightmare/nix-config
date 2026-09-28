-- extract-rar: yazi plugin for extracting .rar archives via unrar.
-- Needed because yazi's built-in extract only drives 7zz/7z, whose Rar5
-- decoder cannot handle WinRAR 7+ (RAR5 v6) archives even with the correct
-- password. Routed from Enter via [open].prepend_rules in yazi.toml.

local function fail(s, ...) error(string.format(s, ...)) end

local M = {}

function M:setup()
	ps.sub_remote("extract-rar", function(args)
		ya.async(function()
			for i, arg in ipairs(args) do
				local in_ = {
					self._id,
					args = { arg, "", noisy = #args == 1 },
					track = i == 1,
				}
				ya.task("plugin", in_):name("Extract " .. arg):spawn()
			end
		end)
	end)
end

function M:init(job)
	local from = job.args[1] and Url(job.args[1])
	if not from then
		fail("No URL provided")
	end

	local to = job.args[2] ~= "" and Url(job.args[2]) or from.parent
	if not to then
		fail("Failed to determine target directory for '%s'", from)
	end

	self.job = { id = job.id, from = from, to = to }
end

function M:entry(job)
	self:init(job)

	local pwd, target, retry = "", nil, false
	while true do
		target, retry = self:try_with(pwd)
		if not retry then
			break
		elseif not job.args.noisy then
			fail("'%s' is password-protected, please extract it individually and enter the password", self.job.from)
		end

		local value, event = ya.input {
			pos = { "top-center", y = 2, w = 50 },
			title = string.format('Password for "%s":', self.job.from.name),
			obscure = true,
		}
		if event == 1 then
			pwd = value
		else
			break
		end
	end

	if target then
		ya.emit("tasks:update_succeed", { job.id, urls = { target }, track = true })
	end
end

function M:try_with(pwd)
	local from, to = self.job.from, self.job.to
	local tmp = fs.unique("dir", to:join(self.tmp_name(from)))
	if not tmp then
		fail("Failed to determine a temporary directory for %s", from)
	end

	-- Never pass a bare -p: unrar would prompt interactively and hang the
	-- task. A bogus password on the first attempt just errors out and trips
	-- the retry flow; unencrypted archives ignore the password entirely.
	local pass = pwd ~= "" and pwd or "yazi-extract-probe"
	local child, err = Command("unrar")
		:arg({ "x", "-y", "-o+", "-p" .. pass, tostring(from), tostring(tmp) })
		:stdin(Command.NULL)
		:stdout(Command.PIPED)
		:stderr(Command.PIPED)
		:spawn()
	if not child then
		fs.remove("dir_all", tmp)
		fail("Failed to start `unrar`, error: " .. tostring(err))
	end

	local output, oerr = child:wait_with_output()
	local out = output and ((output.stdout or "") .. (output.stderr or "")) or ""
	if output and output.status.code ~= 0 and out:lower():find("incorrect", 1, true) then
		fs.remove("dir_all", tmp)
		return nil, true -- Need to retry
	end

	if not output then
		fs.remove("dir_all", tmp)
		fail("unrar failed to output when extracting '%s', error: %s", from, oerr)
	elseif output.status.code ~= 0 then
		fs.remove("dir_all", tmp)
		fail("unrar exited with error code %s when extracting '%s':\n%s", output.status.code, from, out)
	end

	return self:tidy(tmp), false
end

-- Same semantics as the preset extract plugin: a single top-level entry is
-- placed next to the archive, multiple entries go into <archive-stem>/.
function M:tidy(tmp)
	local from, to = self.job.from, self.job.to
	local outs = fs.read_dir(tmp, { limit = 2 })
	if not outs then
		fail("Failed to read the temporary directory '%s' when extracting '%s'", tmp, from)
	elseif #outs == 0 then
		fs.remove("dir", tmp)
		fail("No files extracted from '%s'", from)
	end

	local only = #outs == 1 and outs[1]

	local target = to:join(only and only.name or self.trim_ext(from.name))
	target = fs.unique(only and not only.cha.is_dir and "file" or "dir", target)
	if not target then
		fail("Failed to determine a target for '%s'", from)
	end

	if only and not fs.rename(only.url, target) then
		fail('Failed to move "%s" to "%s"', only.url, target)
	elseif not only and not fs.rename(tmp, target) then
		fail('Failed to move "%s" to "%s"', tmp, target)
	end

	fs.remove("dir", tmp)
	return target
end

function M.tmp_name(url) return ".tmp_" .. ya.hash(string.format("extract-rar//%s//%.10f", url, ya.time())) end

function M.trim_ext(name) return name:gsub("%.rar$", "") end

return M
