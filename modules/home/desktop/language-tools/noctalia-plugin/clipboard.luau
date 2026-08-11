local generation = 0
local separator = string.char(31)
local clipboardKind = ""
local clipboardText = ""
local translatedText = ""

local function trim(value)
  return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function compact(value)
  return trim(value:gsub("[%s\r\n]+", " "))
end

local function shellQuote(value)
  return "'" .. value:gsub("'", "'\"'\"'") .. "'"
end

local function snapshotRows(queryText)
  local results = {}
  if clipboardKind == "image" then
    table.insert(results, {
      id = "ocr",
      title = "识别当前剪贴板图片",
      subtitle = "MiniMax M3 · 原文与简体中文，日文附整段读音",
      glyph = "text-scan-2",
      query = "/ocr run",
      score = 120,
    })
  elseif translatedText ~= "" then
    table.insert(results, {
      id = "copy-translation",
      title = translatedText,
      subtitle = "简体中文 · Bing 在线翻译 · Enter 复制",
      glyph = "language",
      score = 100,
    })
    table.insert(results, {
      id = "translate-again",
      title = "重新翻译",
      subtitle = compact(clipboardText),
      glyph = "refresh",
      score = 80,
    })
  elseif clipboardText ~= "" then
    table.insert(results, {
      id = "translate",
      title = "翻译剪贴板文字为中文",
      subtitle = compact(clipboardText),
      glyph = "language",
      score = 85,
    })
  end

  if clipboardKind == "japanese-text" and clipboardText ~= "" then
    table.insert(results, {
      id = "speak",
      title = "朗读剪贴板日文 · MiniMax",
      subtitle = compact(clipboardText),
      glyph = "volume",
      score = 75,
    })
  end
  launcher.setResults(queryText, results)
end

local function publishTranslation(queryText)
  generation += 1
  local requestGeneration = generation

  launcher.setResults(queryText, {
    {
      id = "loading",
      title = "正在翻译…",
      subtitle = "默认翻译成简体中文，结果会在此处原地更新",
      glyph = "loader",
      score = 100,
    },
  })

  local command = "printf %s "
    .. shellQuote(clipboardText)
    .. " | language-tools translate zh-CN"

  local accepted = noctalia.runAsync(command, function(result)
    if requestGeneration ~= generation then
      return
    end

    translatedText = trim(result.stdout or ""):gsub("[\r\n]+", " · ")
    if result.exitCode == 0 and translatedText ~= "" then
      snapshotRows(queryText)
    else
      launcher.setResults(queryText, {
        {
          id = "error",
          title = "翻译失败",
          subtitle = result.timedOut and "Bing 翻译超过 15 秒" or "请检查网络",
          glyph = "alert-circle",
          score = 100,
        },
        {
          id = "retry",
          title = "重试",
          glyph = "refresh",
          score = 90,
        },
      })
    end
  end, 15000)

  if not accepted then
    launcher.setResults(queryText, {
      {
        id = "error",
        title = "无法启动翻译命令",
        glyph = "alert-circle",
      },
    })
  end
end

local function loadClipboard(queryText)
  generation += 1
  local requestGeneration = generation
  clipboardKind = ""
  clipboardText = ""
  translatedText = ""

  local accepted = noctalia.runAsync("language-tools clipboard-provider", function(result)
    if requestGeneration ~= generation then
      return
    end
    if result.exitCode ~= 0 then
      launcher.setResults(queryText, {})
      return
    end

    local output = (result.stdout or ""):gsub("[\r\n]+$", "")
    local splitAt = string.find(output, separator, 1, true)
    if splitAt == nil then
      launcher.setResults(queryText, {})
      return
    end

    clipboardKind = trim(string.sub(output, 1, splitAt - 1))
    clipboardText = trim(string.sub(output, splitAt + 1))
    snapshotRows(queryText)
  end, 3000)

  if not accepted then
    launcher.setResults(queryText, {})
  end
end

function onQuery(queryText)
  if queryText ~= "" then
    generation += 1
    launcher.setResults(queryText, {})
    return
  end

  loadClipboard(queryText)
end

function onActivate(id)
  if id == "translate" then
    launcher.setQuery("")
    publishTranslation("")
  elseif id == "translate-again" or id == "retry" then
    launcher.setQuery("")
    publishTranslation("")
  elseif id == "copy-translation" and translatedText ~= "" then
    launcher.setQuery("")
    noctalia.copyToClipboard(translatedText, "text/plain")
  elseif id == "speak" and clipboardText ~= "" then
    launcher.setQuery("")
    local command = "printf %s " .. shellQuote(clipboardText) .. " | language-tools speak"
    noctalia.runAsync(command)
  end
end
