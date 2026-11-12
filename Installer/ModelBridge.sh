#!/bin/bash
# CNB 模型转发网关(ModelBridge)启动器
# 部署位置：/opt/youjingsenlin/ModelBridge.sh（由 Installer/Installer.sh 安装）
#
# 为什么需要它：
#   1. CNB 在容器里注入 ACC_PRODUCT_CONFIG_V2，里面已经带着 ai-ide 上游地址与临时令牌，
#      但它是 OpenAI Chat 协议、只接受流式、且只认模型清单里的名字；
#   2. 桌面里预装的一堆 Agent 各用各的协议(Claude Messages / OpenAI Responses / Gemini)，
#      默认还各自要求登录、各自用 claude-sonnet-4-5、gpt-5-codex 之类的模型名。
#   ModelBridge 把同一个上游同时暴露成多种协议入口，并把模型名统一改成 CNB 认识的
#   deepseek-v4-flash，于是 Agent 只要改 baseURL 就能免登录直接用 CNB 的模型。
#
# 本脚本幂等，可反复执行（桌面每次启动、cnb.yml 每个 stage 都会跑一遍）：
#   1. 找 modelbridge 可执行文件；没有就按固定版本 release 下载并校验 sha256；
#   2. 上游交给 ModelBridge 自己解析 ACC_PRODUCT_CONFIG_V2；该变量缺失但存在 CNB_TOKEN 时，
#      按同样格式合成一份再启动（自建 Docker 里通常只注入 CNB_TOKEN）；
#   3. 后台拉起（默认只监听 127.0.0.1:8787，不对外暴露），等 /healthz 就绪；
#   4. 就绪后写 /opt/youjingsenlin/modelbridge.env，供 /etc/profile.d 给 Agent 注入 baseURL。
#
# 用法：ModelBridge.sh start|stop|restart|status|env
#
# 可用环境变量覆盖：
#   MODELBRIDGE=0                  关闭网关：start 直接退出，不下载也不启动
#   MODELBRIDGE_PORT               监听端口，默认 8787
#   MODELBRIDGE_LISTEN             监听地址，默认 127.0.0.1（只给本机 Agent 用）
#   MODELBRIDGE_MODEL              上游模型，默认 deepseek-v4-flash（CNB 侧即 DeepSeek-V4.1-Flash）
#   MODELBRIDGE_VERSION            发行版本，默认 v1.30.3-senlin.1
#   MODELBRIDGE_REPO_URL           发行仓库，默认 https://cnb.cool/magicsenlin/Lab/ModelBridge
#   MODELBRIDGE_SHA256             可选：额外钉死二进制 sha256(未设置时只校验 release 自带 checksums.txt)
#   MODELBRIDGE_BIN                二进制路径，默认 /opt/youjingsenlin/bin/modelbridge
#   MODELBRIDGE_LOG                日志路径，默认 /opt/youjingsenlin/modelbridge.log
#   MODELBRIDGE_NO_INSTALL=1       不允许自动下载，找不到二进制就跳过
#   MODELBRIDGE_METRICS=1          在响应里附带网关统计字段 metrics（默认关闭，避免严格客户端报错）
#   MODELBRIDGE_UPSTREAM_ENDPOINT  覆盖上游 ai-ide 地址（默认由 CNB_API_ENDPOINT/CNB_REPO_SLUG 推导）

set -u

PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin${PATH:+:$PATH}"
export PATH

INSTALL_DIR="/opt/youjingsenlin"

#管理页写入的持久化配置：作为默认值，显式环境变量仍然优先（便于临时换端口/模型）
CONF_FILE="$INSTALL_DIR/modelbridge.conf"
if [ -r "$CONF_FILE" ]; then
  _env_port="${MODELBRIDGE_PORT:-}"
  _env_model="${MODELBRIDGE_MODEL:-}"
  . "$CONF_FILE"
  [ -n "$_env_port" ] && MODELBRIDGE_PORT="$_env_port"
  [ -n "$_env_model" ] && MODELBRIDGE_MODEL="$_env_model"
  unset _env_port _env_model
fi

BIN="${MODELBRIDGE_BIN:-$INSTALL_DIR/bin/modelbridge}"
LOG="${MODELBRIDGE_LOG:-$INSTALL_DIR/modelbridge.log}"
ENV_FILE="$INSTALL_DIR/modelbridge.env"
PID_FILE="$INSTALL_DIR/modelbridge.pid"
PORT="${MODELBRIDGE_PORT:-8787}"
LISTEN="${MODELBRIDGE_LISTEN:-127.0.0.1}"
MODEL="${MODELBRIDGE_MODEL:-deepseek-v4-flash}"
VERSION="${MODELBRIDGE_VERSION:-v1.30.3-senlin.1}"
REPO_URL="${MODELBRIDGE_REPO_URL:-https://cnb.cool/magicsenlin/Lab/ModelBridge}"
BASE_URL="http://127.0.0.1:${PORT}"

say() { printf '%s\n' "$*"; }
log() { printf '%s %s\n' "$(date '+%F %T')" "$*" >>"$LOG" 2>/dev/null || true; }

# 从桌面双击 / CNB stage 进来的 PATH 都很短，这里已经补过标准路径；
# curl 优先，wget 兜底（镜像两者都有，但允许精简镜像只留一个）
fetch() {
  local url="$1" out="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --max-time 300 "$url" -o "$out"
    return
  fi
  wget -qO "$out" "$url"
}

fetch_json() {
  local url="$1" out="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --max-time 60 -H 'Accept: application/json' "$url" -o "$out"
    return
  fi
  wget --header='Accept: application/json' -qO "$out" "$url"
}

detect_arch() {
  case "$(uname -m)" in
    x86_64|amd64) echo amd64 ;;
    aarch64|arm64) echo arm64 ;;
    *) return 1 ;;
  esac
}

find_bin() {
  local c
  [ -x "$BIN" ] && return 0
  for c in /usr/local/bin/modelbridge /usr/bin/modelbridge "$INSTALL_DIR/bin/modelbridge"; do
    if [ -x "$c" ]; then
      BIN="$c"
      return 0
    fi
  done
  if c="$(command -v modelbridge 2>/dev/null)"; then
    BIN="$c"
    return 0
  fi
  return 1
}

# 下载 release 二进制（校验 sha256），装到 $BIN
# 整段放子 shell 里跑，EXIT 陷阱负责删临时目录，任何一条 return 都不会漏清理
install_bin() (
  if [ "${MODELBRIDGE_NO_INSTALL:-0}" = "1" ]; then
    say "MODELBRIDGE_NO_INSTALL=1，不自动下载 modelbridge"
    return 1
  fi
  arch="$(detect_arch)" || {
    say "不支持的架构 $(uname -m)，跳过模型网关"
    return 1
  }
  tmp="$(mktemp -d)" || return 1
  trap 'rm -rf "$tmp"' EXIT

  tag="$VERSION"
  if [ "$tag" = "latest" ]; then
    fetch_json "$REPO_URL/-/releases/latest" "$tmp/latest.json" || {
      say "获取 $REPO_URL 最新版本失败"
      return 1
    }
    tag="$(sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$tmp/latest.json" | head -n 1)"
    [ -n "$tag" ] || {
      say "解析最新版本号失败（$REPO_URL 可能没有发布 release）"
      return 1
    }
  fi

  artifact="modelbridge_linux_${arch}"
  base="$REPO_URL/-/releases/download/$tag"
  say "正在下载 $artifact（$tag）..."
  fetch "$base/$artifact" "$tmp/$artifact" && fetch "$base/checksums.txt" "$tmp/checksums.txt" || {
    say "下载失败：$base/$artifact"
    return 1
  }
  if grep "  ${artifact}\$" "$tmp/checksums.txt" >/dev/null 2>&1; then
    if (cd "$tmp" && grep "  ${artifact}\$" checksums.txt | sha256sum -c - >/dev/null 2>&1); then
      :
    else
      say "sha256 校验失败，放弃安装"
      return 1
    fi
  else
    say "checksums.txt 里没有 $artifact，跳过校验"
  fi
  # 额外钉死：镜像里 pin 的是 amd64 的 hash，自定义场景可用 MODELBRIDGE_SHA256 覆盖；
  # release 的 checksums.txt 与二进制同源，只有这层固定值才能真正防住「同 tag 产物被替换」
  if [ -n "${MODELBRIDGE_SHA256:-}" ]; then
    if ! printf '%s  %s\n' "$MODELBRIDGE_SHA256" "$tmp/$artifact" | sha256sum -c - >/dev/null 2>&1; then
      say "sha256 与 MODELBRIDGE_SHA256 不一致，放弃安装"
      return 1
    fi
  fi

  mkdir -p "$(dirname "$BIN")" || return 1
  install -m 0755 "$tmp/$artifact" "$BIN" || {
    say "安装到 $BIN 失败"
    return 1
  }
  say "已安装 modelbridge -> $BIN（$tag）"
)

healthy() {
  if command -v curl >/dev/null 2>&1; then
    curl -sf -m 2 "$BASE_URL/healthz" >/dev/null 2>&1
    return
  fi
  wget -q -T 2 -O /dev/null "$BASE_URL/healthz" >/dev/null 2>&1
}

find_pid() {
  local p exe
  exe="$(readlink -f "$BIN" 2>/dev/null)"
  if [ -s "$PID_FILE" ]; then
    p="$(tr -dc '0-9' <"$PID_FILE")"
    if [ -n "$p" ] && kill -0 "$p" 2>/dev/null; then
      printf '%s\n' "$p"
      return 0
    fi
  fi
  for p in $(pgrep -x modelbridge 2>/dev/null); do
    if [ "$(readlink -f "/proc/$p/exe" 2>/dev/null)" = "$exe" ]; then
      printf '%s\n' "$p"
      return 0
    fi
  done
  return 1
}

# 上游：优先用 CNB 注入的 ACC_PRODUCT_CONFIG_V2；缺失但有 CNB_TOKEN 时合成等价配置，
# 让 ModelBridge 仍然走它的 Codebuddy 适配（内置改写规则、IDE 标识头、强制流式）。
ensure_upstream_env() {
  local ep tok api slug
  if [ -n "${ACC_PRODUCT_CONFIG_V2:-}" ]; then
    return 0
  fi
  api="${CNB_API_ENDPOINT:-https://api.cnb.cool}"
  slug="${CNB_REPO_SLUG:-}"
  tok="${CNB_TOKEN:-}"
  ep="${MODELBRIDGE_UPSTREAM_ENDPOINT:-}"
  if [ -z "$ep" ] && [ -n "$slug" ]; then
    ep="${api%/}/${slug}/-/ai-ide"
  fi
  case "$ep$tok" in
    *'"'*|*\\*) say "上游地址或令牌含有引号/反斜杠，跳过模型网关"; return 1 ;;
  esac
  if [ -z "$ep" ] || [ -z "$tok" ]; then
    say "未找到 CNB 模型上游（ACC_PRODUCT_CONFIG_V2 / CNB_TOKEN），跳过模型网关"
    return 1
  fi
  ACC_PRODUCT_CONFIG_V2="{\"endpoint\":\"${ep}\",\"networkEnvironment\":\"internal\",\"authentication\":{\"type\":\"custom-token\",\"attributes\":{\"token\":\"${tok}\"}}}"
  export ACC_PRODUCT_CONFIG_V2
  say "已用 CNB_TOKEN 合成上游配置：$ep"
}

# 写给 Agent 用的环境变量（不含任何密钥：网关走的是容器内注入的上游令牌）
write_agent_env() {
  mkdir -p "$INSTALL_DIR" 2>/dev/null || true
  #必须用 export：shell 里 `VAR=值` 只是当前 shell 的变量，不会传给 Agent 子进程
  cat >"$ENV_FILE" <<EOF
# 由 Installer/ModelBridge.sh 生成（网关就绪后才会写），供 /etc/profile.d 与 agent-env.sh 注入。
# 想恢复成各 Agent 自己登录：rm -f $ENV_FILE 后重开终端。
export OPENAI_BASE_URL=$BASE_URL/v1
export OPENAI_API_BASE=$BASE_URL/v1
export OPENAI_API_KEY=cnb-local
export OPENAI_MODEL=$MODEL
export ANTHROPIC_BASE_URL=$BASE_URL
export ANTHROPIC_AUTH_TOKEN=cnb-local
export ANTHROPIC_API_KEY=cnb-local
export GOOGLE_GEMINI_BASE_URL=$BASE_URL
export GEMINI_API_KEY=cnb-local
EOF
  chmod 644 "$ENV_FILE" 2>/dev/null || true
}

start() {
  if [ "${MODELBRIDGE:-1}" = "0" ]; then
    say "MODELBRIDGE=0，跳过模型网关"
    return 0
  fi

  # pid / env 都写在 INSTALL_DIR；用 MODELBRIDGE_BIN 指到别处时这里可能还不存在
  mkdir -p "$INSTALL_DIR" 2>/dev/null || true

  if healthy; then
    say "模型网关已在运行：$BASE_URL"
    write_agent_env
    return 0
  fi

  if ! find_bin; then
    if ! install_bin; then
      say "跳过模型网关：没有可用的 modelbridge（可手动放置到 $BIN，或用 MODELBRIDGE_BIN 指定）"
      return 1
    fi
  fi

  if ! ensure_upstream_env; then
    return 1
  fi

  mkdir -p "$(dirname "$LOG")" 2>/dev/null || true
  say "正在启动模型网关（端口 $PORT，上游模型 $MODEL）..."
  # setsid：脱离当前会话，CNB stage / 终端窗口结束后不被一起收掉
  LISTEN_ADDR="${LISTEN}:${PORT}" \
  TARGET_MODEL="$MODEL" \
  TARGET_MODEL_LIST="$MODEL" \
  RESPONSE_METRICS="$( [ "${MODELBRIDGE_METRICS:-0}" = "1" ] && echo true || echo false )" \
  LOG_LEVEL="${MODELBRIDGE_LOG_LEVEL:-info}" \
  setsid nohup "$BIN" >>"$LOG" 2>&1 </dev/null &
  echo $! >"$PID_FILE" 2>/dev/null || true

  local i=0
  while [ "$i" -lt 100 ]; do
    if healthy; then
      write_agent_env
      log "网关已就绪：$BASE_URL（$BIN）"
      say "模型网关就绪：$BASE_URL（日志 $LOG）"
      return 0
    fi
    sleep 0.2
    i=$((i + 1))
  done

  say "模型网关 20 秒内未就绪，最近日志："
  [ -s "$LOG" ] && tail -n 15 "$LOG"
  return 1
}

stop() {
  local p
  if p="$(find_pid)"; then
    kill "$p" 2>/dev/null || true
    local i=0
    while [ "$i" -lt 25 ] && kill -0 "$p" 2>/dev/null; do
      sleep 0.2
      i=$((i + 1))
    done
    kill -9 "$p" 2>/dev/null || true
    say "已停止模型网关（pid $p）"
  else
    say "模型网关未在运行"
  fi
  #网关停了就把 Agent 环境文件一起撤掉：否则新开的终端仍指向一个没人监听的端口，
  #表现为 Agent 一直超时而不是回到自己的登录方式（Agent 包装器还会再探活一次兜底）
  rm -f "$PID_FILE" "$ENV_FILE"
}

#终端里（双击桌面「模型网关」快捷方式）看完状态再退，避免窗口一闪而过；
#cnb.yml 的 stage 里 stdin 不是 tty，不会停在这里
pause_if_tty() {
  [ -t 0 ] || return 0
  say ""
  say "按回车关闭窗口（30 秒后自动关闭）"
  read -r -t 30 _ 2>/dev/null || true
}

status() {
  local p
  say "监听地址：$BASE_URL    上游模型：$MODEL"
  say "二进制：$BIN"
  say "日志：$LOG"
  say "Agent 环境：$ENV_FILE"
  if p="$(find_pid)"; then
    say "进程：$p"
  else
    say "进程：未运行"
  fi
  if healthy; then
    printf '健康检查：'
    if command -v curl >/dev/null 2>&1; then
      curl -fsS -m 3 "$BASE_URL/healthz" && printf '\n'
    else
      wget -qO- -T 3 "$BASE_URL/healthz" && printf '\n'
    fi
    say "状态：运行中"
    pause_if_tty
    return 0
  fi
  say "状态：未运行"
  pause_if_tty
  return 1
}

case "${1:-start}" in
  start) start ;;
  stop) stop ;;
  restart) stop; start ;;
  status) status ;;
  env) [ -f "$ENV_FILE" ] && cat "$ENV_FILE" || say "还没有生成 $ENV_FILE（网关未就绪）" ;;
  *)
    say "用法：$0 start|stop|restart|status|env"
    exit 2
    ;;
esac
