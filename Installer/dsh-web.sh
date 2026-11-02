#!/bin/bash
# DeepSeek Harness(dsh) Web 快捷启动器
# 部署位置：/opt/youjingsenlin/dsh-web.sh（由 Installer/Installer.sh 安装）
#
# 背景：
#   1. `dsh` 是交互式 CLI，只有 `dsh web` 才会起 Web 服务，直接点快捷方式起不来
#   2. `dsh web` 前台运行，终端窗口一关服务就跟着退出
#   3. 服务已经在跑时再点一次，会因为端口被占用报错
#
# 本脚本的行为：
#   1. 没有实例在跑：用 setsid + nohup 把 `dsh web` 放到后台，前台窗口可以随时关掉
#   2. 已经有实例在跑：只在默认浏览器里打开一次页面，不再起第二个进程
#   3. 存活判定：进程存在 + 端口有 HTTP 响应，两者都满足才算“已启动”
#
# 可用环境变量覆盖：
#   DSH_WEB_PORT     首选端口，默认 3080(与 `dsh web` 自身的默认端口一致)；被占用时自动往后找一个空闲端口
#   DSH_WEB_TIMEOUT  等待服务就绪的秒数，默认 180（首次启动要初始化 profile，会慢）
#   DSH_WEB_LOG      日志文件，默认 ~/.dsh-web.log
#   DSH_WEB_WORKDIR  工作目录，同时也是 dsh 的 workspace 根，默认 ~
#   DSH_BIN          dsh 可执行文件路径，默认从 PATH 里找

set -u

HOME="${HOME:-$(getent passwd "$(id -u)" | cut -d: -f6)}"
[ -n "${HOME:-}" ] || HOME=/

DSH_BIN="${DSH_BIN:-}"
FIRST_PORT="${DSH_WEB_PORT:-3080}"
TIMEOUT="${DSH_WEB_TIMEOUT:-180}"
LOG="${DSH_WEB_LOG:-$HOME/.dsh-web.log}"
PORT_FILE="$HOME/.dsh-web.port"
WORKDIR="${DSH_WEB_WORKDIR:-$HOME}"
LOCK_FILE="${TMPDIR:-/tmp}/dsh-web-launch-$(id -u).lock"

#从桌面双击进来时 PATH 往往很短，补上标准路径
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin${PATH:+:$PATH}"

say() { printf '%s\n' "$*"; }

log() {
  printf '%s %s\n' "$(date '+%F %T')" "$*" >>"$LOG" 2>/dev/null || true
}

tail_log() {
  [ -s "$LOG" ] || return 0
  say "---------- 最近日志($LOG) ----------"
  tail -n 20 "$LOG"
  say "------------------------------------"
}

#出错时留住窗口，方便看到原因（只有终端里运行才等）
pause_on_error() {
  [ -t 0 ] || return 0
  say ""
  say "按回车关闭窗口(60 秒后自动关闭)"
  read -r -t 60 _ 2>/dev/null || true
}

find_dsh() {
  local c
  if [ -n "$DSH_BIN" ] && [ -x "$DSH_BIN" ]; then
    return 0
  fi
  if c="$(command -v dsh 2>/dev/null)"; then
    DSH_BIN="$c"
    return 0
  fi
  for c in /usr/local/bin/dsh /usr/bin/dsh "$HOME/.local/bin/dsh"; do
    if [ -x "$c" ]; then
      DSH_BIN="$c"
      return 0
    fi
  done
  return 1
}

#列出所有 dsh web 进程号(按 argv 精确匹配，避免误伤命令行里只是出现 dsh/web 字样的进程)
dsh_web_pids() {
  local p a base is_dsh is_web
  local -a argv
  for p in $(pgrep -f dsh 2>/dev/null); do
    [ "$p" = "$$" ] && continue
    argv=()
    mapfile -d '' -t argv 2>/dev/null <"/proc/$p/cmdline" || continue
    [ "${#argv[@]}" -gt 0 ] || continue
    base="$(basename "${argv[0]}")"
    is_dsh=0
    is_web=0
    [ "$base" = dsh ] && is_dsh=1
    for a in "${argv[@]}"; do
      case "$a" in
        web) is_web=1 ;;
        dsh|*/dsh|*@deepseek-ai/dsh*|*dsh*bin.js*) is_dsh=1 ;;
      esac
    done
    if [ "$is_dsh" = 1 ] && [ "$is_web" = 1 ]; then
      printf '%s\n' "$p"
    fi
  done
}

#列出某个进程正在监听的 TCP 端口
listening_ports() {
  local p="$1"
  if command -v ss >/dev/null 2>&1; then
    ss -Hltnp 2>/dev/null | grep -F "pid=${p}," | awk '{print $4}' | sed 's/.*://' | sort -u
    return 0
  fi
  if command -v lsof >/dev/null 2>&1; then
    lsof -Pan -p "$p" -iTCP -sTCP:LISTEN 2>/dev/null | awk 'NR > 1 {print $9}' | sed 's/.*://' | sort -u
    return 0
  fi
  return 1
}

#推断正在运行的 dsh web 端口：启动参数 > 实际监听端口 > 上次记录 > 日志里的 URL
dsh_port() {
  local pids p cmd port
  pids="$(dsh_web_pids)"
  [ -n "$pids" ] || return 1

  for p in $pids; do
    cmd="$(tr '\0' '\n' 2>/dev/null <"/proc/$p/cmdline")"
    port="$(printf '%s\n' "$cmd" | awk '/^--port$/{getline; print; exit} /^--port=/{sub(/^--port=/, ""); print; exit}')"
    if [ -n "$port" ]; then
      printf '%s\n' "$port"
      return 0
    fi
  done

  for p in $pids; do
    port="$(listening_ports "$p" 2>/dev/null | head -n 1)"
    if [ -n "$port" ]; then
      printf '%s\n' "$port"
      return 0
    fi
  done

  port="$(tr -dc '0-9' 2>/dev/null <"$PORT_FILE")"
  if [ -n "$port" ]; then
    printf '%s\n' "$port"
    return 0
  fi

  port="$(sed -n 's|.*dsh web: http://[^:/]*:\([0-9][0-9]*\).*|\1|p' "$LOG" 2>/dev/null | tail -n 1)"
  if [ -n "$port" ]; then
    printf '%s\n' "$port"
    return 0
  fi

  return 1
}

#端口上能拿到 HTTP 状态码即视为就绪(不校验具体状态，避免被 401/403 误判)
port_ready() {
  local port="$1" code
  if command -v curl >/dev/null 2>&1; then
    code="$(curl -s -o /dev/null -m 2 -w '%{http_code}' "http://127.0.0.1:${port}/" 2>/dev/null)"
    [ -n "$code" ] && [ "$code" != "000" ]
    return
  fi
  if command -v wget >/dev/null 2>&1; then
    wget -q -T 2 -O /dev/null "http://127.0.0.1:${port}/" >/dev/null 2>&1
    return
  fi
  port_busy "$port"
}

#端口是否已被占用
port_busy() {
  (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null
}

#从首选端口开始找一个空闲端口
pick_port() {
  local p="$1" n=0
  while [ "$n" -lt 20 ]; do
    if ! port_busy "$p"; then
      printf '%s\n' "$p"
      return 0
    fi
    p=$((p + 1))
    n=$((n + 1))
  done
  return 1
}

open_url() {
  local url="$1" b
  for b in xdg-open sensible-browser gio firefox chromium chromium-browser google-chrome; do
    command -v "$b" >/dev/null 2>&1 || continue
    if [ "$b" = gio ]; then
      setsid gio open "$url" >>"$LOG" 2>&1 </dev/null 9>&- &
    else
      setsid "$b" "$url" >>"$LOG" 2>&1 </dev/null 9>&- &
    fi
    log "打开页面 $url($b)"
    return 0
  done
  return 1
}

#参数: 端口；返回 0 就绪 / 1 超时 / 2 进程已退出
wait_ready() {
  local port="$1" waited=0 dead=0
  while [ "$waited" -lt "$TIMEOUT" ]; do
    if port_ready "$port"; then
      return 0
    fi
    if [ -n "$(dsh_web_pids)" ]; then
      dead=0
    else
      #连续几次既没有进程也没有端口响应，才判定启动失败(避开进程刚拉起的竞态)
      dead=$((dead + 1))
      if [ "$dead" -ge 5 ] && ! port_ready "$port"; then
        return 2
      fi
    fi
    sleep 1
    waited=$((waited + 1))
    if [ $((waited % 10)) -eq 0 ]; then
      say "  仍在启动中... ${waited}s"
    fi
  done
  return 1
}

start_dsh() {
  local port="$1"
  printf '%s\n' "$port" >"$PORT_FILE" 2>/dev/null || true
  log "启动: $DSH_BIN web --port $port (workdir=$WORKDIR)"
  cd "$WORKDIR" 2>/dev/null || cd "$HOME" 2>/dev/null || cd /
  #9>&- 关掉启动锁的 fd，否则后台的 dsh/浏览器会一直占着锁，下次点击就进不来
  setsid nohup "$DSH_BIN" web --port "$port" >>"$LOG" 2>&1 </dev/null 9>&- &
  disown 2>/dev/null || true
}

#别的启动流程正在进行：等它就绪后把页面打开，避免重复起进程
wait_other_launcher() {
  local waited=0 port
  while [ "$waited" -lt "$TIMEOUT" ]; do
    port="$(dsh_port 2>/dev/null)"
    if [ -n "$port" ] && port_ready "$port"; then
      open_url "http://127.0.0.1:${port}/"
      return 0
    fi
    sleep 1
    waited=$((waited + 1))
  done
  return 1
}

main() {
  if ! find_dsh; then
    say "找不到 dsh 命令，镜像里可能没装 @deepseek-ai/dsh"
    pause_on_error
    exit 1
  fi

  if command -v flock >/dev/null 2>&1; then
    exec 9>"$LOCK_FILE"
    if ! flock -n 9; then
      say "另一个启动流程正在进行，等待服务就绪..."
      if wait_other_launcher; then
        say "已在浏览器打开页面"
        exit 0
      fi
      say "等待超时，请查看日志：$LOG"
      tail_log
      pause_on_error
      exit 1
    fi
  fi

  local pids port want
  pids="$(dsh_web_pids)"

  #已经启动：只开页面，不再起进程
  if [ -n "$pids" ]; then
    port="$(dsh_port || printf '%s' "$FIRST_PORT")"
    say "dsh web 已在运行(pid: $(printf '%s' "$pids" | tr '\n' ' ')，端口 ${port})"
    if ! port_ready "$port"; then
      say "端口暂时没有响应，等待就绪..."
      wait_ready "$port"
      case $? in
        0) ;;
        2)
          say "dsh web 进程已退出"
          tail_log
          pause_on_error
          exit 1
          ;;
        *)
          say "等待 ${TIMEOUT}s 仍未就绪"
          tail_log
          pause_on_error
          exit 1
          ;;
      esac
    fi
    if open_url "http://127.0.0.1:${port}/"; then
      say "已在浏览器打开 http://127.0.0.1:${port}/"
    else
      say "没有找到可用的浏览器，请手动打开 http://127.0.0.1:${port}/"
    fi
    exit 0
  fi

  #没有启动：挑一个空闲端口后后台拉起
  want="$(tr -dc '0-9' 2>/dev/null <"$PORT_FILE")"
  [ -n "$want" ] || want="$FIRST_PORT"
  if ! port="$(pick_port "$want")"; then
    say "端口 ${want} 起连续 20 个端口都被占用，请用 DSH_WEB_PORT 指定其他端口"
    pause_on_error
    exit 1
  fi
  if [ "$port" != "$want" ]; then
    say "端口 ${want} 已被占用，改用 ${port}"
  fi

  say "正在启动 dsh web(端口 ${port})，首次启动要初始化 profile，请稍候..."
  start_dsh "$port"

  wait_ready "$port"
  case $? in
    0) ;;
    2)
      say "dsh web 启动失败，进程已退出"
      tail_log
      pause_on_error
      exit 1
      ;;
    *)
      say "等待 ${TIMEOUT}s 仍未就绪"
      tail_log
      pause_on_error
      exit 1
      ;;
  esac

  if open_url "http://127.0.0.1:${port}/"; then
    say "已在浏览器打开 http://127.0.0.1:${port}/"
  else
    say "没有找到可用的浏览器，请手动打开 http://127.0.0.1:${port}/"
  fi
}

main "$@"
