local activeQuery = ""
local activeValues = {}
local generation = 0

local function trim(value)
  return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function shellQuote(value)
  return "'" .. value:gsub("'", "'\"'\"'") .. "'"
end

local function parseQuery(text)
  local target, query = text:match("^([%a][%a%-]*)%s*:%s*(.+)$")
  if target ~= nil then
    return trim(query), {
      { code = target, label = target },
    }
  end

  return trim(text), {
    { code = "zh-CN", label = "中文" },
  }
end

local function publish(queryText, targets, failures)
  local results = {}

  for _, target in ipairs(targets) do
    local value = activeValues[target.code]
    if value ~= nil then
      table.insert(results, {
        id = target.code,
        title = value,
        subtitle = target.label .. " · Bing 在线翻译 · Enter 复制",
        glyph = "language",
        score = target.code == "zh-CN" and 100 or 90,
      })
    end
  end

  if #results == 0 then
    if failures >= #targets then
      results = {
        {
          id = "error",
          title = "翻译失败",
          subtitle = "请检查网络，或确认 translate-shell 可用",
          glyph = "alert-circle",
        },
      }
    else
      results = {
        {
          id = "loading",
          title = "正在查询…",
          subtitle = "默认翻译成中文",
          glyph = "loader",
        },
      }
    end
  end

  launcher.setResults(queryText, results)
end

function onQuery(queryText)
  generation += 1
  local requestGeneration = generation
  activeQuery = queryText
  activeValues = {}

  local text, targets = parseQuery(queryText)
  if text == "" then
    launcher.setResults(queryText, {
      {
        id = "hint",
        title = "输入要翻译的文字",
        subtitle = "默认中文；复制文字后直接打开 Launcher；其他语言：/tr en:日本語",
        glyph = "language",
      },
    })
    return
  end

  local failures = 0
  publish(queryText, targets, failures)

  for _, target in ipairs(targets) do
    local command = "printf %s "
      .. shellQuote(text)
      .. " | language-tools translate "
      .. shellQuote(target.code)

    local accepted = noctalia.runAsync(command, function(result)
      if requestGeneration ~= generation or queryText ~= activeQuery then
        return
      end

      local value = trim(result.stdout or ""):gsub("[\r\n]+", " · ")
      if result.exitCode == 0 and value ~= "" then
        activeValues[target.code] = value
      else
        failures += 1
      end

      publish(queryText, targets, failures)
    end, 15000)

    if not accepted then
      failures += 1
      publish(queryText, targets, failures)
    end
  end
end

function onActivate(id)
  local value = activeValues[id]
  if value ~= nil then
    noctalia.copyToClipboard(value, "text/plain")
  end
end
