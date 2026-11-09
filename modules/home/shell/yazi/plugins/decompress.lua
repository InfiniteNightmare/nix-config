-- yazi builtin extract only drives 7zz/7z: no WinRAR 7+ (RAR5 v6), no zips
-- with junk prepended by disguise shells, no content-based detection. Tools
-- are tried in one universal chain regardless of the extension (disguised
-- files break the name contract: a .rar can hide a zip, a .zip a 7z). A probe
-- password on the first attempt is safe (unencrypted archives ignore it) and
-- a wrong password just re-triggers the prompt.

local PROBE = "yazi-extract-probe"

-- Each tool runs via `sh -c` with paths/password passed through environment
-- variables (injection-safe), and stderr merged into stdout so a single
-- incremental read sees everything.
local tools = {
	unrar = {
		script = "exec unrar x -y -o+ -p\"$YA_P\" \"$YA_F\" \"$YA_T\" 2>&1",
		-- "corrupt header" = header-encrypted rar with a wrong password
		retry = { "incorrect", "corrupt header" },
	},
	unzip = {
		script = "exec unzip -o -P\"$YA_P\" \"$YA_F\" -d \"$YA_T\" 2>&1",
		retry = { "incorrect password" },
		-- WinZip AES entries are skipped as "unsupported compression method
		-- 99" even with the right password: hand the file to the next tool
		skip = { "unsupported compression method" },
		-- unzip exits 1 for benign warnings like "extra bytes at beginning"
		warn_ok = true,
	},
	bsdtar = {
		script = "exec bsdtar --passphrase \"$YA_P\" -x -vf \"$YA_F\" -C \"$YA_T\" 2>&1",
		retry = { "incorrect" },
	},
	-- Forced-zip mode: 7zz's zip reader locates the EOCD through prepended
	-- junk (png shells) that breaks bsdtar, and handles zip64 + AES
	["7zz-zip"] = {
		script = "exec 7zz x -tzip -y -p\"$YA_P\" -o\"$YA_T\" \"$YA_F\" 2>&1",
		retry = { "wrong password" },
	},
	-- Plain 7zz for genuine 7z content (incl. encrypted)
	["7zz"] = {
		script = "exec 7zz x -y -p\"$YA_P\" -o\"$YA_T\" \"$YA_F\" 2>&1",
		retry = { "wrong password" },
	},
}

-- One universal chain: content decides, not the extension
local chain = { "unrar", "unzip", "bsdtar", "7zz-zip", "7zz" }

local function fail(s, ...) error(string.format(s, ...)) end

local M = {}

function M:setup()
	ps.sub_remote("decompress", function(args)
		ya.async(function()
			for i, arg in ipairs(args) do
				ya.task("plugin", {
					self._id,
					args = { arg, "", noisy = #args == 1 },
					track = i == 1,
				}):name("Extract " .. arg):spawn()
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
		-- try_with returns plain strings: Url userdata cannot survive the
		-- yields inside the chain (GC destructs them -> "userdata has been
		-- destructed" on next use)
		ya.emit("tasks:update_succeed", { job.id, urls = { Url(target) }, track = true })
		-- ya.notify and os.execute are unavailable in task context; go through
		-- the desktop daemon via Command instead so the toast survives even if
		-- yazi loses focus. Missing notify-send just no-ops.
		local content = target:find("^/tmp/", 1, true)
				and ("Extracted to " .. target .. " (name not allowed next to the archive)")
			or ("Extracted to " .. (target:match("[^/]+$") or "the archive's directory"))
		Command("notify-send"):arg({ "-a", "Yazi", "Decompress", content }):spawn()
	end
end

-- AES key derivation costs ~1s per entry: a wrong password scanned across a
-- gallery-sized archive takes minutes before the prompt shows up. Instead
-- test-decrypt the first encrypted entry up front — one derivation, seconds.
-- Returns true when the password is wrong (caller triggers the retry flow);
-- false when unencrypted, probe inconclusive, or the password passes.
function M:probe_password(pass, from, tmp)
	local lst = Command("7zz")
		:arg({ "l", "-tzip", "-p" .. pass, "-slt", tostring(from) })
		:stdout(Command.PIPED)
		:stderr(Command.NULL)
		:spawn()
	if not lst then
		return false
	end
	local output = lst:wait_with_output()
	if not (output and output.status.code == 0) then
		return false -- not readable as zip (mp4 shell etc.): the chain decides
	end

	local name
	for line in (output.stdout or ""):gmatch("[^\r\n]+") do
		local path = line:match("^Path = (.+)$")
		if path then
			name = path
		elseif line:match("^Encrypted = %+") and name then
			break
		end
	end
	if not name then
		return false -- nothing encrypted: no password will ever be needed
	end

	local test = Command("7zz")
		:arg({ "x", "-tzip", "-p" .. pass, "-y", "-o" .. tostring(tmp), tostring(from), name })
		:stdin(Command.NULL)
		:stdout(Command.NULL)
		:stderr(Command.PIPED)
		:spawn()
	if not test then
		return false
	end
	local output = test:wait_with_output()
	local out = output and ((output.stdout or "") .. (output.stderr or "")) or ""
	return out:lower():find("wrong password", 1, true) ~= nil
end

-- Returns target, retry. Never wrap spawn()/read_line()/wait() in pcall:
-- they yield across the C boundary, which is an uncatchable error that
-- kills the task.
function M:try_with(pwd)
	local from, to = self.job.from, self.job.to
	local pass = pwd ~= "" and pwd or PROBE

	local tmp = fs.unique("dir", to:join(self.tmp_name(from)))
	if not tmp then
		fail("Failed to determine a temporary directory for %s", from)
	end

	if self:probe_password(pass, from, tmp) then
		fs.remove("dir_all", tmp)
		return nil, true
	end

	local status, result = self:attempt(pass, from, tmp)
	if status == "retry" then
		return nil, true
	end

	local err = ""
	if status == "ok" then
		local moved, is_dir = self:tidy(result, to)
		if moved then
			return tostring(moved), false
		end
		-- rename into the archive's directory failed (target fs rejected the
		-- name) — the ntfs fallback below still applies
	else
		err = result
	end

	-- The archive may sit on a filesystem that rejects extracted filenames
	-- (ntfs3 + raw zip names): redo the chain with scratch space on ext4 and
	-- move back whatever the target fs accepts. (stat -f reports ntfs3 as
	-- "UNKNOWN (0x...)", so detect via findmnt.)
	local st = Command("findmnt"):arg({ "-no", "FSTYPE", "-T", tostring(to) }):output()
	if not (st and st.status.code == 0 and st.stdout:lower():find("ntfs")) then
		fail("All extractors failed:%s", err)
	end

	local work = fs.unique("dir", Url("/tmp/decompress"))
	local tmp2 = fs.unique("dir", work:join(self.tmp_name(from)))
	if self:probe_password(pass, from, tmp2) then
		fs.remove("dir_all", work)
		return nil, true
	end
	local status, result = self:attempt(pass, from, tmp2)
	if status == "retry" then
		fs.remove("dir_all", work)
		return nil, true
	elseif status ~= "ok" then
		fs.remove("dir_all", work)
		fail("All extractors failed:%s", err)
	end

	local target, is_dir = self:tidy(tmp2, work)
	-- fs.unique fails (nil) when the raw name is illegal on the target fs
	local final = fs.unique(is_dir and "dir" or "file", to:join(target.name))
	if final and fs.rename(target, final) then
		fs.remove("dir_all", work)
		return tostring(final), false
	end
	-- Name not allowed on the target fs: leave the result in /tmp and point
	-- the user at it (further layers usually extract fine there).
	return tostring(target), false
end

-- Runs the tool chain, extracting into the given scratch dir. Returns
-- "ok" (results in tmp, not yet tidied), "retry", or "fail" + error text.
function M:attempt(pass, from, tmp)
	local err = ""

	for _, name in ipairs(chain) do
		local tool = tools[name]
		local child, spawn_err = Command("sh")
			:arg({ "-c", tool.script })
			:env("YA_P", pass)
			:env("YA_F", tostring(from))
			:env("YA_T", tostring(tmp))
			:stdin(Command.NULL)
			:stdout(Command.PIPED)
			:stderr(Command.PIPED)
			:spawn()

		if not child then
			err = err .. "\n" .. name .. ": failed to start: " .. tostring(spawn_err)
		else
			local output = child:wait_with_output()
			local out = output and ((output.stdout or "") .. (output.stderr or "")) or ""
			local code = output and output.status.code
			local lower = out:lower()
			local matched, skipped = false, false
			for _, sig in ipairs(tool.retry) do
				if lower:find(sig, 1, true) then
					matched = true
					break
				end
			end
			for _, sig in ipairs(tool.skip or {}) do
				if lower:find(sig, 1, true) then
					skipped = true
				end
			end

			if matched then
				fs.remove("dir_all", tmp)
				return "retry"
			end

			-- skipped = this tool cannot handle the content at all (e.g. unzip
			-- vs WinZip AES): move on to the next tool even on "success"
			local got = (code == 0 or (tool.warn_ok and code == 1)) and not skipped
			if got then
				self:fix_perms(tmp)
				return "ok", tmp
			end
			err = err .. "\n" .. name .. ": " .. out
		end
	end

	fs.remove("dir_all", tmp)
	return "fail", err
end

-- Move the extraction result next to the archive; returns the final url or
-- nil if the target filesystem rejected the name.
function M:tidy(tmp, dest)
	local from = self.job.from
	local outs = fs.read_dir(tmp, { limit = 2 })
	if not outs then
		fail("Failed to read the temporary directory '%s' when extracting '%s'", tmp, from)
	elseif #outs == 0 then
		fs.remove("dir", tmp)
		fail("No files extracted from '%s'", from)
	end

	local only = #outs == 1 and outs[1]

	local target = dest:join(only and only.name or self.trim_ext(from.name))
	target = fs.unique(only and not only.cha.is_dir and "file" or "dir", target)
	if not target then
		fail("Failed to determine a target for '%s'", from)
	end

	if only and not fs.rename(only.url, target) then
		return nil
	elseif not only and not fs.rename(tmp, target) then
		return nil
	end

	fs.remove("dir", tmp)
	return target, only and not only.cha.is_dir
end

function M.tmp_name(url) return ".tmp_" .. ya.hash(string.format("decompress//%s//%.10f", url, ya.time())) end

function M.trim_ext(name) return name:gsub("%.rar$", ""):gsub("%.zip$", "") end

-- Windows-packaged zips can carry garbage directory modes (e.g. 000): the
-- extraction succeeds but the tree is unnavigable. Make it user-usable.
function M:fix_perms(root)
	Command("chmod")
		:arg({ "-R", "u+rwX", tostring(root) })
		:spawn()
end

return M
