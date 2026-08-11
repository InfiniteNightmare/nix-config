local generation = 0
local activeQuery = ""
local lastOcrCommand = "language-tools ocr-clipboard"
local sourceText = ""
local readingText = ""
local translationText = ""
local speechText = ""
local detectedLanguage = ""
local separator = string.char(31)

local function trim(value)
  return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function compact(value)
  return trim(value:gsub("[%s\r\n]+", " "))
end

local function shellQuote(value)
  return "'" .. value:gsub("'", "'\"'\"'") .. "'"
end

local function resultRows(queryText, includeStart)
  local results = {}

  if includeStart then
    table.insert(results, {
      id = "start",
      title = "识别当前剪贴板图片",
      subtitle = "MiniMax M3 · 原文与中文会在这里原地出现",
      glyph = "text-scan-2",
      score = 120,
    })
  end

  if sourceText ~= "" then
    table.insert(results, {
      id = "copy-source",
      title = compact(sourceText),
      subtitle = "原文 · Enter 复制",
      glyph = "text-recognition",
      score = 110,
    })
  end

  if readingText ~= "" then
    table.insert(results, {
      id = "copy-reading",
      title = compact(readingText),
      subtitle = "整段日文读音 · Enter 复制",
      glyph = "text-recognition",
      score = 105,
    })
  end

  if translationText ~= "" then
    table.insert(results, {
      id = "copy-translation",
      title = compact(translationText),
      subtitle = "简体中文 · Enter 复制",
      glyph = "language",
      score = 100,
    })
  end

  if detectedLanguage == "ja" and speechText ~= "" then
    table.insert(results, {
      id = "speak-source",
      title = "朗读原文",
      subtitle = "MiniMax Speech 2.8 HD · 日语",
      glyph = "volume",
      score = 80,
    })
  end

  launcher.setResults(queryText, results)
end

local function publishError(queryText, message)
  launcher.setResults(queryText, {
    {
      id = "error",
      title = "图片识别失败",
      subtitle = message,
      glyph = "alert-circle",
      score = 100,
    },
    {
      id = "retry",
      title = "重试",
      subtitle = "保持当前 Launcher，不会关闭再打开",
      glyph = "refresh",
      score = 90,
    },
  })
end

local function parseResult(output)
  local fields = {}
  local startAt = 1
  for _ = 1, 4 do
    local splitAt = string.find(output, separator, startAt, true)
    if splitAt == nil then
      return nil
    end
    table.insert(fields, string.sub(output, startAt, splitAt - 1))
    startAt = splitAt + 1
  end
  table.insert(fields, string.sub(output, startAt))
  return fields
end

local function startOcr(queryText, command)
  generation += 1
  local requestGeneration = generation
  activeQuery = queryText
  lastOcrCommand = command

  launcher.setResults(queryText, {
    {
      id = "loading",
      title = "正在识别并翻译…",
      subtitle = "相同图片优先读取私有缓存；新图片才请求 MiniMax M3",
      glyph = "loader",
      score = 100,
    },
  })

  local accepted = noctalia.runAsync(command, function(result)
    if requestGeneration ~= generation or queryText ~= activeQuery then
      return
    end

    if result.exitCode ~= 0 then
      local message = trim(result.stderr or ""):gsub("[\r\n]+", " ")
      if result.timedOut then
        message = "图片识别超过 60 秒，请重试"
      elseif message == "" then
        message = "请检查剪贴板图片、网络和 MiniMax Token Plan"
      end
      publishError(queryText, message)
      return
    end

    local fields = parseResult(trim(result.stdout or ""))
    if fields == nil then
      publishError(queryText, "无法解析 MiniMax 返回结果")
      return
    end

    sourceText = trim(fields[1])
    readingText = trim(fields[2])
    translationText = trim(fields[3])
    speechText = trim(fields[4])
    detectedLanguage = trim(fields[5]):lower()
    if sourceText == "" or translationText == "" then
      publishError(queryText, "MiniMax 没有返回完整的原文和中文翻译")
      return
    end

    resultRows(queryText, false)
  end, 60000)

  if not accepted then
    publishError(queryText, "Noctalia 无法启动图片识别命令")
  end
end

function onQuery(queryText)
  if queryText == "" then
    generation += 1
    activeQuery = queryText
    resultRows(queryText, true)
    return
  end

  local requestId = queryText:match("^path%-(request%.[%w]+)$")
  if requestId ~= nil then
    startOcr(queryText, "language-tools ocr-path " .. shellQuote(requestId))
    return
  end

  if queryText == "view" then
    generation += 1
    activeQuery = queryText
    resultRows(queryText, false)
    return
  end

  if queryText == "run" then
    startOcr(queryText, "language-tools ocr-clipboard")
    return
  end

  if queryText:match("^retry%-%d+$") then
    startOcr(queryText, lastOcrCommand)
    return
  end

  generation += 1
  activeQuery = queryText
  launcher.setResults(queryText, {})
end

function onActivate(id)
  if id == "start" then
    launcher.setQuery("run")
  elseif id == "retry" then
    launcher.setQuery("retry-" .. tostring(generation))
  elseif id == "copy-source" then
    launcher.setQuery("view")
    noctalia.copyToClipboard(sourceText, "text/plain")
  elseif id == "copy-reading" then
    launcher.setQuery("view")
    noctalia.copyToClipboard(readingText, "text/plain")
  elseif id == "copy-translation" then
    launcher.setQuery("view")
    noctalia.copyToClipboard(translationText, "text/plain")
  elseif id == "speak-source" and speechText ~= "" then
    launcher.setQuery("view")
    local command = "printf %s " .. shellQuote(speechText) .. " | language-tools speak"
    noctalia.runAsync(command)
  end
end
