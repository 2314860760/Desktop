#!/bin/bash
# ModelBridge 本地管理页启动器
# 管理页是一个单文件 Node 服务（镜像装了 npm，node 一定在），只监听 127.0.0.1:8788，
# 用来查看网关状态、改模型/端口、看日志、复制各 Agent 的接入配置。
# 用法：ModelBridgeAdmin.sh start|stop|restart|status|open

set -u

PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin${PATH:+:$PATH}"
export PATH

INSTALL_DIR="${MODELBRIDGE_INSTALL_DIR:-/opt/youjingsenlin}"
APP="$INSTALL_DIR/ModelBridgeAdmin.js"
PAGE="$INSTALL_DIR/ModelBridgeAdmin.html"
PORT="${MODELBRIDGE_ADMIN_PORT:-8788}"
LOG="$INSTALL_DIR/modelbridge-admin.log"
PID_FILE="$INSTALL_DIR/modelbridge-admin.pid"
URL="http://127.0.0.1:${PORT}/"

say() { printf '%s\n' "$*"; }

healthy() {
  if command -v curl >/dev/null 2>&1; then
    curl -sf -m 2 "${URL}healthz" >/dev/null 2>&1
    return
  fi
  wget -q -T 2 -O /dev/null "${URL}healthz" >/dev/null 2>&1
}

start() {
  if healthy; then
    say "管理页已在运行：$URL"
    return 0
  fi
  local node_bin=""
  node_bin="$(command -v node 2>/dev/null || command -v nodejs 2>/dev/null || true)"
  if [ -z "$node_bin" ]; then
    say "未找到 node/nodejs，跳过模型网关管理页"
    return 1
  fi
  if [ ! -f "$APP" ] || [ ! -f "$PAGE" ]; then
    say "缺少管理页文件：$APP / $PAGE"
    return 1
  fi

  mkdir -p "$INSTALL_DIR" 2>/dev/null || true
  setsid nohup "$node_bin" "$APP" >>"$LOG" 2>&1 </dev/null &
  echo $! >"$PID_FILE" 2>/dev/null || true

  local i=0
  while [ "$i" -lt 30 ]; do
    if healthy; then
      say "管理页就绪：$URL"
      return 0
    fi
    sleep 0.2
    i=$((i + 1))
  done
  say "管理页启动失败，日志：$LOG"
  [ -s "$LOG" ] && tail -n 10 "$LOG"
  return 1
}

stop() {
  local p=""
  if [ -s "$PID_FILE" ]; then
    p="$(tr -dc '0-9' <"$PID_FILE")"
  fi
  if [ -n "$p" ] && kill -0 "$p" 2>/dev/null; then
    kill "$p" 2>/dev/null || true
    say "已停止模型网关管理页（pid $p）"
  else
    # pid 文件丢了就按脚本路径找一次，避免重装后残留（node 或 nodejs 都匹配）
    p="$(pgrep -f "$APP" 2>/dev/null | head -n 1)"
    [ -n "$p" ] && kill "$p" 2>/dev/null || true
    [ -n "$p" ] && say "已停止模型网关管理页（pid $p）" || say "模型网关管理页未在运行"
  fi
  rm -f "$PID_FILE"
}

status() {
  say "地址：$URL"
  say "日志：$LOG"
  if healthy; then
    say "状态：运行中"
    if command -v curl >/dev/null 2>&1; then
      curl -fsS -m 3 "${URL}api/status" 2>/dev/null | head -c 600
      printf '\n'
    fi
    return 0
  fi
  say "状态：未运行"
  return 1
}

open_page() {
  start || true
  if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$URL" >/dev/null 2>&1 &
  else
    say "请手动打开：$URL"
  fi
}

case "${1:-start}" in
  start) start ;;
  stop) stop ;;
  restart) stop; start ;;
  status) status ;;
  open) open_page ;;
  *)
    say "用法：$0 start|stop|restart|status|open"
    exit 2
    ;;
esac
