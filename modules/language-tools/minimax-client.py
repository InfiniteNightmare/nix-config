import base64
import fcntl
import hashlib
import json
import mimetypes
import os
import re
import shlex
import ssl
import sys
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path


ENV_FILE = Path("@MINIMAX_ENV_FILE@")
SYSTEM_CA_BUNDLE = Path("/etc/ssl/certs/ca-bundle.crt")
OCR_MODEL = "MiniMax-M3"
OCR_MAX_IMAGE_BYTES = 10 * 1024 * 1024
SPEECH_MODEL = "speech-2.8-hd"
SPEECH_VOICE_ID = "Japanese_GracefulMaiden"
SPEECH_LANGUAGE_BOOST = "Japanese"
SPEECH_SPEED = 0.92
SPEECH_MAX_TEXT_CHARS = 10_000
MAX_CACHE_FILES = 128
CACHE_MAX_AGE_DAYS = 30
OCR_MAX_CACHE_BYTES = 16 * 1024 * 1024
SPEECH_MAX_CACHE_BYTES = 256 * 1024 * 1024
FIELD_SEPARATOR = "\x1f"

OCR_PROMPT = (
    "精确识别图片中的全部可见文字，并翻译成简体中文。"
    "保持原文的阅读顺序、标点和换行；不要解释、补写或纠错。"
    "如果原文是日文，结合整句和画面上下文同时生成 reading_kana 与 speech_text。"
    "reading_kana 用于学习展示：逐句对应原文，把汉字、々、数字、日期、助数词、"
    "拉丁缩写和固有名词转换为标准日语读法；图片中可见的振假名优先；"
    "保留片假名、促音、拗音、长音符、标点和有意义的段落，助词保持 は、へ、を。"
    "speech_text 用于语音合成：内容与 reading_kana 相同，但把助词按实际发音写成"
    "わ、え、お。两个字段都不得加入汉字、罗马字、括号注音、解释或额外内容。"
    "如果原文不是日文，reading_kana 和 speech_text 都必须是空字符串。"
    "只输出一个 JSON 对象，字段必须为 source_text、reading_kana、speech_text、"
    "translation_zh、detected_language，所有字段值均为字符串；"
    "detected_language 必须使用 ISO 639-1 代码，例如日文固定为 ja。"
)


class ClientError(RuntimeError):
    pass


def ensure_private_directory(path: Path) -> Path:
    path.mkdir(mode=0o700, parents=True, exist_ok=True)
    path.chmod(0o700)
    return path


def cache_root() -> Path:
    default_cache = str(Path.home() / ".cache")
    xdg_cache = Path(os.environ.get("XDG_CACHE_HOME", default_cache))
    return ensure_private_directory(xdg_cache / "language-tools")


def cache_directory(name: str) -> Path:
    return ensure_private_directory(cache_root() / name)


def load_environment(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError as error:
        raise ClientError(f"无法读取 MiniMax 密钥文件: {error}") from error

    for raw_line in lines:
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("export "):
            line = line.removeprefix("export ").lstrip()
        key, separator, raw_value = line.partition("=")
        if not separator:
            continue
        parsed = shlex.split(raw_value, comments=True)
        values[key.strip()] = parsed[0] if parsed else ""
    return values


def first_value(values: dict[str, str], names: tuple[str, ...]) -> str:
    for name in names:
        value = values.get(name, "").strip()
        if value:
            return value
    return ""


def client_environment() -> dict[str, str]:
    environment = dict(os.environ)
    if ENV_FILE.is_file():
        environment.update(load_environment(ENV_FILE))
    return environment


def api_key(environment: dict[str, str]) -> str:
    key = first_value(
        environment,
        (
            "MINIMAX_API_KEY",
            "MINIMAX_CN_API_KEY",
            "ANTHROPIC_API_KEY",
            "ANTHROPIC_AUTH_TOKEN",
        ),
    )
    if not key:
        raise ClientError("密钥文件中没有可用的 MiniMax API Key")
    return key


def api_endpoint(environment: dict[str, str], path: str) -> str:
    host = first_value(
        environment,
        ("MINIMAX_API_HOST", "MINIMAX_BASE_URL", "ANTHROPIC_BASE_URL"),
    )
    if not host:
        host = (
            "https://api.minimaxi.com"
            if environment.get("MINIMAX_CN_API_KEY", "").strip()
            else "https://api.minimax.io"
        )
    host = host.rstrip("/")
    if host.endswith("/anthropic"):
        host = host.removesuffix("/anthropic")
    if host.endswith("/v1"):
        host = host.removesuffix("/v1")
    return f"{host}/v1/{path.lstrip('/')}"


def tls_context() -> ssl.SSLContext:
    configured_bundle = os.environ.get("SSL_CERT_FILE", "").strip()
    if configured_bundle:
        return ssl.create_default_context(cafile=configured_bundle)
    if SYSTEM_CA_BUNDLE.is_file():
        return ssl.create_default_context(cafile=str(SYSTEM_CA_BUNDLE))
    return ssl.create_default_context()


def api_error_message(body: str) -> str:
    try:
        details = json.loads(body)
    except json.JSONDecodeError:
        return body.strip()
    api_error = details.get("error", {}) or {}
    base_response = details.get("base_resp", {}) or {}
    message = api_error.get("message") or base_response.get("status_msg") or body
    return str(message).strip()


def request_json(
    environment: dict[str, str],
    endpoint: str,
    payload: dict[str, object],
    label: str,
    timeout: int,
) -> dict[str, object]:
    request = urllib.request.Request(
        api_endpoint(environment, endpoint),
        data=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {api_key(environment)}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(
            request,
            timeout=timeout,
            context=tls_context(),
        ) as response:
            value = json.load(response)
    except urllib.error.HTTPError as error:
        body = error.read().decode("utf-8", errors="replace")
        raise ClientError(
            f"{label} HTTP {error.code}: {api_error_message(body)}"
        ) from error
    except (OSError, TimeoutError) as error:
        raise ClientError(f"无法连接 {label}: {error}") from error
    if not isinstance(value, dict):
        raise ClientError(f"{label} 返回格式无效")
    return value


def cache_lock(directory: Path, *, blocking: bool = True):
    lock_path = directory / ".cache.lock"
    lock_file = lock_path.open("a+", encoding="utf-8")
    lock_path.chmod(0o600)
    operation = fcntl.LOCK_EX if blocking else fcntl.LOCK_EX | fcntl.LOCK_NB
    try:
        fcntl.flock(lock_file, operation)
    except BlockingIOError:
        lock_file.close()
        return None
    return lock_file


def prune_cache(directory: Path, pattern: str, max_bytes: int) -> None:
    oldest_allowed = time.time() - CACHE_MAX_AGE_DAYS * 24 * 60 * 60
    candidates: list[tuple[float, int, Path]] = []
    for path in directory.glob(pattern):
        try:
            path.chmod(0o600)
            stat = path.stat()
        except OSError:
            continue
        if stat.st_mtime < oldest_allowed:
            path.unlink(missing_ok=True)
        else:
            candidates.append((stat.st_mtime, stat.st_size, path))
    candidates.sort(reverse=True)
    retained_bytes = 0
    for index, (_, size, path) in enumerate(candidates):
        keep = index == 0 or (
            index < MAX_CACHE_FILES and retained_bytes + size <= max_bytes
        )
        if keep:
            retained_bytes += size
        else:
            path.unlink(missing_ok=True)


def write_private_file(path: Path, payload: bytes) -> None:
    file_descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{path.stem}-",
        suffix=path.suffix,
        dir=path.parent,
    )
    temporary_path = Path(temporary_name)
    try:
        os.fchmod(file_descriptor, 0o600)
        with os.fdopen(file_descriptor, "wb") as output:
            output.write(payload)
        temporary_path.replace(path)
    except BaseException:
        try:
            os.close(file_descriptor)
        except OSError:
            pass
        temporary_path.unlink(missing_ok=True)
        raise


def image_mime_type(path: Path, image: bytes) -> str:
    header = image[:16]
    if header.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png"
    if header.startswith(b"\xff\xd8\xff"):
        return "image/jpeg"
    if header.startswith((b"GIF87a", b"GIF89a")):
        return "image/gif"
    if header.startswith(b"RIFF") and header[8:12] == b"WEBP":
        return "image/webp"
    guessed = mimetypes.guess_type(path.name)[0] or "image/png"
    if guessed in {"image/jpeg", "image/png", "image/gif", "image/webp"}:
        return guessed
    return "image/png"


def image_data_url(path: Path, image: bytes) -> str:
    encoded = base64.b64encode(image).decode("ascii")
    return f"data:{image_mime_type(path, image)};base64,{encoded}"


def strip_code_fence(value: str) -> str:
    value = re.sub(r"<think>.*?</think>", "", value, flags=re.DOTALL).strip()
    if not value.startswith("```"):
        return value
    lines = value.splitlines()
    if lines:
        lines.pop(0)
    if lines and lines[-1].strip() == "```":
        lines.pop()
    return "\n".join(lines).strip()


def parse_json_object(content: str) -> object:
    cleaned = strip_code_fence(content)
    try:
        return json.loads(cleaned)
    except json.JSONDecodeError:
        start = cleaned.find("{")
        end = cleaned.rfind("}")
        if start < 0 or end <= start:
            raise
        return json.loads(cleaned[start:end + 1])


def normalize_ocr_result(value: object) -> dict[str, str]:
    if not isinstance(value, dict):
        raise ValueError("MiniMax 没有返回 JSON 对象")

    def string_field(name: str) -> str:
        return str(value.get(name) or "").replace(FIELD_SEPARATOR, "").strip()

    result = {
        "source_text": string_field("source_text"),
        "reading_kana": string_field("reading_kana"),
        "speech_text": string_field("speech_text"),
        "translation_zh": string_field("translation_zh"),
        "detected_language": string_field("detected_language").lower(),
    }
    if not result["source_text"]:
        raise ValueError("MiniMax 没有识别出原文")
    if not result["translation_zh"]:
        raise ValueError("MiniMax 没有返回中文翻译")
    if result["detected_language"] in {"ja", "jp", "japanese", "日语", "日文"}:
        result["detected_language"] = "ja"
        if not result["reading_kana"]:
            raise ValueError("MiniMax 没有返回日文读音")
        if not result["speech_text"]:
            raise ValueError("MiniMax 没有返回日文朗读文本")
    return result


def ocr_cache_key(image: bytes) -> str:
    material = json.dumps(
        {
            "model": OCR_MODEL,
            "prompt": OCR_PROMPT,
            "fields": [
                "source_text",
                "reading_kana",
                "speech_text",
                "translation_zh",
                "detected_language",
            ],
        },
        ensure_ascii=False,
        sort_keys=True,
    ).encode("utf-8")
    digest = hashlib.sha256(material)
    digest.update(b"\x00")
    digest.update(image)
    return digest.hexdigest()


def read_ocr_cache(path: Path) -> dict[str, str] | None:
    if not path.is_file() or path.stat().st_size == 0:
        return None
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
        result = normalize_ocr_result(value)
    except (OSError, json.JSONDecodeError, ValueError):
        path.unlink(missing_ok=True)
        return None
    path.chmod(0o600)
    os.utime(path)
    return result


def fetch_ocr(path: Path, image: bytes) -> dict[str, str]:
    environment = client_environment()
    payload: dict[str, object] = {
        "model": OCR_MODEL,
        "messages": [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": OCR_PROMPT},
                    {
                        "type": "image_url",
                        "image_url": {
                            "url": image_data_url(path, image),
                            "detail": "high",
                            "max_long_side_pixel": 2048,
                        },
                    },
                ],
            }
        ],
        "temperature": 0,
        "max_tokens": 4096,
    }
    response = request_json(
        environment,
        "chat/completions",
        payload,
        "MiniMax API",
        45,
    )
    try:
        content = response["choices"][0]["message"]["content"]  # type: ignore[index]
        if isinstance(content, list):
            content = "".join(
                str(part.get("text", ""))
                for part in content
                if isinstance(part, dict)
            )
        return normalize_ocr_result(parse_json_object(str(content)))
    except (KeyError, IndexError, TypeError, json.JSONDecodeError, ValueError) as error:
        raise ClientError(f"无法解析 MiniMax 返回结果: {error}") from error


def print_ocr_result(result: dict[str, str]) -> None:
    fields = (
        result["source_text"],
        result["reading_kana"],
        result["translation_zh"],
        result["speech_text"],
        result["detected_language"],
    )
    sys.stdout.write(FIELD_SEPARATOR.join(fields) + "\n")


def ocr(path: Path) -> None:
    if not path.is_file():
        raise ClientError("图片文件不存在")
    try:
        image = path.read_bytes()
    except OSError as error:
        raise ClientError(f"无法读取图片: {error}") from error
    if len(image) > OCR_MAX_IMAGE_BYTES:
        raise ClientError("图片超过 MiniMax API 的 10 MB 限制")
    if not image:
        raise ClientError("图片文件为空")

    directory = cache_directory("ocr")
    cache_path = directory / f"{ocr_cache_key(image)}.json"
    with cache_lock(directory):
        result = read_ocr_cache(cache_path)
        if result is None:
            result = fetch_ocr(path, image)
            write_private_file(
                cache_path,
                json.dumps(result, ensure_ascii=False).encode("utf-8"),
            )
        prune_cache(directory, "*.json", OCR_MAX_CACHE_BYTES)
    print_ocr_result(result)


def speech_cache_key(text: str) -> str:
    material = {
        "model": SPEECH_MODEL,
        "text": text,
        "stream": False,
        "language_boost": SPEECH_LANGUAGE_BOOST,
        "output_format": "hex",
        "voice_setting": {
            "voice_id": SPEECH_VOICE_ID,
            "speed": SPEECH_SPEED,
            "vol": 1,
            "pitch": 0,
        },
        "audio_setting": {
            "sample_rate": 32000,
            "bitrate": 128000,
            "format": "mp3",
            "channel": 1,
        },
        "subtitle_enable": False,
    }
    encoded = json.dumps(
        material,
        ensure_ascii=False,
        sort_keys=True,
    ).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def speech_payload(text: str) -> dict[str, object]:
    return {
        "model": SPEECH_MODEL,
        "text": text,
        "stream": False,
        "language_boost": SPEECH_LANGUAGE_BOOST,
        "output_format": "hex",
        "voice_setting": {
            "voice_id": SPEECH_VOICE_ID,
            "speed": SPEECH_SPEED,
            "vol": 1,
            "pitch": 0,
        },
        "audio_setting": {
            "sample_rate": 32000,
            "bitrate": 128000,
            "format": "mp3",
            "channel": 1,
        },
        "subtitle_enable": False,
    }


def fetch_speech(text: str) -> bytes:
    environment = client_environment()
    response = request_json(
        environment,
        "t2a_v2",
        speech_payload(text),
        "MiniMax Speech",
        30,
    )
    base_response = response.get("base_resp", {}) or {}
    if isinstance(base_response, dict) and base_response.get("status_code") not in (
        None,
        0,
    ):
        raise ClientError(
            f"MiniMax Speech API: {base_response.get('status_msg', '请求失败')}"
        )
    data = response.get("data", {}) or {}
    audio_hex = data.get("audio", "") if isinstance(data, dict) else ""
    try:
        audio = bytes.fromhex(str(audio_hex))
    except ValueError as error:
        raise ClientError("MiniMax Speech 返回了无效音频") from error
    if not audio:
        raise ClientError("MiniMax Speech 没有返回音频")
    return audio


def speak(text: str) -> None:
    text = text.replace("\x00", "").strip()
    if not text:
        raise ClientError("没有可朗读的文字")
    if len(text) > SPEECH_MAX_TEXT_CHARS:
        raise ClientError("朗读文本超过 MiniMax 的 10000 字符限制")

    directory = cache_directory("speech")
    output_path = directory / f"{speech_cache_key(text)}.mp3"
    with cache_lock(directory):
        if output_path.is_file() and output_path.stat().st_size > 0:
            output_path.chmod(0o600)
            os.utime(output_path)
        else:
            write_private_file(output_path, fetch_speech(text))
        prune_cache(directory, "*.mp3", SPEECH_MAX_CACHE_BYTES)
    print(output_path)


def prune_all_caches() -> None:
    policies = (
        ("ocr", "*.json", OCR_MAX_CACHE_BYTES),
        ("speech", "*.mp3", SPEECH_MAX_CACHE_BYTES),
    )
    for name, pattern, max_bytes in policies:
        directory = cache_directory(name)
        lock_file = cache_lock(directory, blocking=False)
        if lock_file is None:
            continue
        with lock_file:
            prune_cache(directory, pattern, max_bytes)


def main() -> int:
    os.umask(0o077)
    if len(sys.argv) < 2 or sys.argv[1] not in {"ocr", "prune", "speak"}:
        print(
            "usage: minimax-client {ocr IMAGE|prune|speak [TEXT]}",
            file=sys.stderr,
        )
        return 2

    try:
        if sys.argv[1] == "ocr":
            if len(sys.argv) != 3:
                raise ClientError("usage: minimax-client ocr IMAGE")
            ocr(Path(sys.argv[2]))
        elif sys.argv[1] == "prune":
            if len(sys.argv) != 2:
                raise ClientError("usage: minimax-client prune")
            prune_all_caches()
        else:
            text = " ".join(sys.argv[2:]) if len(sys.argv) > 2 else sys.stdin.read()
            speak(text)
    except ClientError as error:
        print(error, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
