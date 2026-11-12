#!/bin/bash
# 桌面快捷方式启动 Agent 前的环境包装器
# 为什么需要：KDE 的 .desktop 里 `Exec=claude` 是直接 exec，不经过登录 shell，
# /etc/profile.d 不会被加载，Agent 会当成全新环境、要求登录。
# 这里在 exec 之前加载网关 env，并且先探活：网关没起来就不注入，保持 Agent 原有登录方式。
# 用法：agent-env.sh <命令> [参数...]

set -u

ENV_FILE="${MODELBRIDGE_ENV_FILE:-/opt/youjingsenlin/modelbridge.env}"

if [ "$#" -eq 0 ]; then
  echo "用法：$0 <命令> [参数...]" >&2
  exit 2
fi

if [ -r "$ENV_FILE" ]; then
  # 先只从 env 文件里取端口，不在当前 shell 里 source，避免把探活逻辑污染成网关变量
  port="$(sed -n -E 's|^(export +)?OPENAI_BASE_URL=http://127\.0\.0\.1:([0-9]+)/v1$|\2|p' "$ENV_FILE" | tail -n 1)"
  [ -n "$port" ] || port=8787
  if command -v curl >/dev/null 2>&1; then
    if curl -sf -m 1 "http://127.0.0.1:${port}/healthz" >/dev/null 2>&1; then
      set -a
      . "$ENV_FILE"
      set +a
    fi
  elif command -v wget >/dev/null 2>&1; then
    if wget -q -T 1 -O /dev/null "http://127.0.0.1:${port}/healthz" >/dev/null 2>&1; then
      set -a
      . "$ENV_FILE"
      set +a
    fi
  fi
fi

exec "$@"
