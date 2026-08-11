umask 077

cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/language-tools"
pending_dir="$cache_dir/pending"

ensure_cache_dir() {
  mkdir -p -- "$cache_dir"
  chmod 700 -- "$cache_dir"
  mkdir -p -- "$pending_dir"
  chmod 700 -- "$pending_dir"
  find "$pending_dir" -maxdepth 1 -type f -name 'request.*' -mmin +60 -delete
}

notify_error() {
  notify-send --app-name="语言工具" --icon=dialog-error "$1" "$2"
}

clipboard_types() {
  timeout 2 wl-paste --list-types 2>/dev/null || true
}

inspect_clipboard() {
  types="$(clipboard_types)"
  if printf '%s\n' "$types" | grep -qE '^image/'; then
    printf 'image\n'
    return
  fi

  text="$(wl-paste --no-newline --type text 2>/dev/null || true)"
  if test -z "$text"; then
    printf 'none\n'
  elif printf '%s' "$text" | grep -qP '[\x{3040}-\x{30ff}]'; then
    printf 'japanese-text\n'
  else
    printf 'text\n'
  fi
}

ocr_clipboard() {
  mime="$(clipboard_types | grep -m1 -E '^image/' || true)"
  if test -z "$mime"; then
    printf '%s\n' "剪贴板中没有图片，请先使用 Niri 截图或复制图片。" >&2
    return 1
  fi

  image_file="$(mktemp --suffix=.clipboard-image)"
  trap 'rm -f -- "$image_file"' EXIT HUP INT TERM
  if ! wl-paste --type "$mime" >"$image_file"; then
    printf '%s\n' "无法读取剪贴板图片，图片数据可能已经失效。" >&2
    return 1
  fi
  minimax-client ocr "$image_file"
}

ocr_path() {
  request_id="${1:-}"
  if ! printf '%s' "$request_id" | grep -qE '^request\.[[:alnum:]]+$'; then
    printf '%s\n' "图片请求编号无效。" >&2
    return 2
  fi
  ensure_cache_dir
  request_file="$pending_dir/$request_id"
  if ! IFS= read -r image_path <"$request_file" \
    || ! test -f "$image_path"; then
    printf '%s\n' "Noctalia 没有提供有效的图片文件。" >&2
    return 1
  fi

  if minimax-client ocr "$image_path"; then
    rm -f -- "$request_file"
  else
    return 1
  fi
}

prepare_ocr_path() {
  image_path="${1:-}"
  if ! test -f "$image_path"; then
    notify_error "无法读取图片" "Noctalia 没有导出有效的图片文件。"
    return 1
  fi

  ensure_cache_dir
  request_file="$(mktemp "$pending_dir/request.XXXXXX")"
  request_id="${request_file##*/}"
  printf '%s\n' "$image_path" >"$request_file"
  chmod 600 -- "$request_file"
  exec "@NOCTALIA@" msg panel-open launcher "/ocr path-$request_id"
}

speak() {
  text="$(cat)"
  if test -z "$text"; then
    notify_error "没有可朗读的文字" "请先复制或识别日文。"
    return 1
  fi

  if ! output="$(printf '%s' "$text" | minimax-client speak 2>&1)"; then
    output="${output//$'\n'/ }"
    notify_error "朗读失败" "${output:-无法生成日语语音，请检查网络和 MiniMax Token Plan。}"
    return 1
  fi
  if ! test -s "$output"; then
    notify_error "朗读失败" "MiniMax 没有返回有效音频。"
    return 1
  fi
  exec mpv --no-config --no-video --audio-display=no --really-quiet -- "$output"
}

clipboard_provider() {
  kind="$(inspect_clipboard)"
  case "$kind" in
    image)
      printf 'image\037\n'
      return
      ;;
    japanese-text | text) ;;
    *) return 1 ;;
  esac
  text="$(wl-paste --no-newline --type text 2>/dev/null || true)"
  text="${text//$'\x1f'/}"
  test -n "$text" || return 1
  printf '%s\037%s\n' "$kind" "${text:0:1200}"
}

translate_text() {
  target="${1:-zh-CN}"
  if ! printf '%s' "$target" | grep -qE '^[[:alpha:]][[:alpha:]-]*$'; then
    printf '%s\n' "无效的目标语言代码。" >&2
    return 2
  fi
  text="$(cat)"
  test -n "$text" || return 2
  printf '%s' "$text" \
    | timeout 15 trans -engine bing -brief -no-ansi -s auto -t "$target"
}

inspect() {
  ensure_cache_dir
  minimax-client prune >/dev/null 2>&1 || true
  inspect_clipboard
}

action="${1:-inspect}"
shift || true
case "$action" in
  inspect) inspect ;;
  ocr-clipboard) ocr_clipboard ;;
  ocr-path) ocr_path "$@" ;;
  prepare-ocr-path) prepare_ocr_path "$@" ;;
  clipboard-provider) clipboard_provider ;;
  speak) speak ;;
  translate) translate_text "$@" ;;
  *)
    notify_error "未知操作" "$action"
    exit 2
    ;;
esac
