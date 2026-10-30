# .ide/Dockerfile
FROM docker.cnb.cool/set/file/dockerimages/desktop:basement
#安装PHP/JDK/npm/ruby/mariadb/redis/memcached (合并为一层，减少镜像层数)
RUN apt-mark hold tzdata && \
    apt update && (apt upgrade -y || true) && \
    apt install -y -o APT::Install-Recommends=true \
        php openjdk-17-jdk npm ruby-full mariadb-server redis memcached && \
    rm -rf /var/lib/apt/lists/*

#安装JDK
RUN wget https://download.java.net/java/GA/jdk24.0.1/24a58e0e276943138bf3e963e6291ac2/9/GPL/openjdk-24.0.1_linux-x64_bin.tar.gz -O /opt/openjdk24.0.1.tar.gz && tar -zxvf /opt/openjdk24.0.1.tar.gz && rm -rf /opt/openjdk24.0.1.tar.gz
#RUN 安装其他JDK?

#安装.net core(添加微软源与安装SDK合并为一层)
RUN wget https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb -O /tmp/packages-microsoft-prod.deb && \
    dpkg -i /tmp/packages-microsoft-prod.deb && rm -f /tmp/packages-microsoft-prod.deb && \
    apt-get update && apt-get install -y dotnet-sdk-8.0 dotnet-sdk-9.0 dotnet-sdk-10.0 && \
    rm -rf /var/lib/apt/lists/*

#安装golang
RUN wget https://golang.google.cn/dl/go1.24.2.linux-amd64.tar.gz -O /opt/go1.24.2.linux-amd64.tar.gz && rm -rf /usr/local/go && tar -C /usr/local -xzf /opt/go1.24.2.linux-amd64.tar.gz && rm -rf /opt/go1.24.2.linux-amd64.tar.gz

#其他IDE构建
RUN cd /opt/ && git clone https://cnb.cool/set/File/idea.git && chmod +x /opt/idea/Installer.sh && bash /opt/idea/Installer.sh && rm -rf /opt/idea 


#安装其他软件(微信/QQ/vscode/dbeaver/CodeBuddy IDE/CrossOver 合并为一层，减少镜像层数)
RUN apt update && \
    echo "==> 微信" && \
    wget https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_x86_64.deb -O /opt/WeChatLinux_x86_64.deb && \
    apt install -y /opt/WeChatLinux_x86_64.deb && \
    rm -f /opt/WeChatLinux_x86_64.deb && \
    echo "==> QQ" && \
    PKG_URL="https://qqdl.gtimg.cn/qqfile/QQNTV2/9.9.36/release/9ee04bef/QQ_3.2.34_260924_amd64_01.deb" && \
    SIGN_URL=$(wget -qO- --header='content-type: application/json' --header='x-oidb: {"uint32_command":"0x9b8e","uint32_service_type":1}' --header='Origin: https://im.qq.com' --header='Referer: https://im.qq.com/' --post-data="{\"url\":\"$PKG_URL\"}" 'https://im.qq.com/http2rpc/gotrpc/noauth/trpc.qqntv2.urlsign.UrlSign/GetSign' | sed -n 's/.*"url":"\([^"]*\)".*/\1/p' | sed 's|\\/|/|g') && \
    wget -U "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" "$SIGN_URL" -O /opt/QQ_3.2.34_260924_amd64_01.deb && \
    apt install -y /opt/QQ_3.2.34_260924_amd64_01.deb && \
    rm -f /opt/QQ_3.2.34_260924_amd64_01.deb && \
    echo "==> VSCode" && \
    wget "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64" -O /opt/vscode.deb && \
    apt install -y /opt/vscode.deb && \
    rm -f /opt/vscode.deb && \
    echo "==> DBeaver" && \
    wget https://dbeaver.io/files/dbeaver-ce_latest_amd64.deb -O /opt/dbeaver.deb && \
    apt install -y /opt/dbeaver.deb && \
    rm -f /opt/dbeaver.deb && \
    echo "==> CodeBuddy IDE" && \
    wget https://download.codebuddy.cn/aiide/linux-x64/CodeBuddy-linux-x64-4.12.0.37847260-b4c35ed0-cn.deb -O /opt/codebuddy-cn.deb && \
    apt install -y /opt/codebuddy-cn.deb && \
    rm -f /opt/codebuddy-cn.deb && \
    echo "==> CrossOver" && \
    wget https://media.codeweavers.com/pub/crossover/cxlinux/demo/crossover_26.0.0-1.deb -O /opt/crossover_26.0.0-1.deb && \
    apt install -y /opt/crossover_26.0.0-1.deb && \
    rm -f /opt/crossover_26.0.0-1.deb && \
    rm -rf /var/lib/apt/lists/*


#安装 AI Agent CLI (全部使用各家官方 npm 包 / 官方安装脚本)
#CodeBuddy 要求 Node >= 18.20、ClaudeCode 要求 Node >= 22，apt 自带的 18.19 不满足，改用官方 Node 22 LTS
RUN NODE_VER=$(wget -qO- https://nodejs.org/dist/index.json | grep -o '"version":"v22[^"]*"' | head -n1 | cut -d'"' -f4) && \
    wget "https://nodejs.org/dist/${NODE_VER}/node-${NODE_VER}-linux-x64.tar.xz" -O /opt/node.tar.xz && \
    tar -xJf /opt/node.tar.xz -C /usr/local --strip-components=1 && rm -rf /opt/node.tar.xz
#WorkBuddy CLI 与 CodeBuddy 共用一个 npm 包(命令名 codebuddy)
#命令与官方 npm 包对应关系:
#  claude=@anthropic-ai/claude-code  dsh=@deepseek-ai/dsh         codex=@openai/codex
#  gemini=@google/gemini-cli         copilot=@github/copilot      qwen=@qwen-code/qwen-code
#  amp=@sourcegraph/amp              crush=@charmland/crush       opencode=opencode-ai
#  cn=@continuedev/cli               iflow=@iflow-ai/iflow-cli
RUN npm install -g \
        @tencent-ai/codebuddy-code @anthropic-ai/claude-code @deepseek-ai/dsh \
        @openai/codex @google/gemini-cli @github/copilot @qwen-code/qwen-code \
        @sourcegraph/amp @charmland/crush opencode-ai @continuedev/cli @iflow-ai/iflow-cli \
    && npm cache clean --force
#Cursor CLI 只提供官方安装脚本，脚本固定装到 ~/.local/bin，这里指定 HOME 后软链到 /usr/local/bin
RUN HOME=/opt/cursor-home bash -c 'curl -fsSL https://cursor.com/install | bash' && ln -sf /opt/cursor-home/.local/bin/cursor-agent /usr/local/bin/cursor-agent
#自检：命令存在且能输出版本号
RUN for c in codebuddy claude dsh codex gemini copilot qwen amp crush opencode cn iflow cursor-agent; do command -v "$c" >/dev/null || { echo "缺少 $c"; exit 1; }; printf '%-12s %s\n' "$c" "$("$c" --version 2>&1 | head -n1)"; done

#安装 WorkBuddy 桌面端(版本从腾讯官方更新服务动态获取，自动跟随最新版)
RUN META=$(curl -fsSL "https://copilot.tencent.com/v2/update?platform=workbuddy-linux-x64-deb") && URL=$(printf '%s' "$META" | sed -n 's/.*"url":"\([^"]*\)".*/\1/p') && SHA=$(printf '%s' "$META" | sed -n 's/.*"sha256hash":"\([^"]*\)".*/\1/p') && wget "$URL" -O /opt/workbuddy.deb && echo "$SHA  /opt/workbuddy.deb" | sha256sum -c - && apt update && apt install -y /opt/workbuddy.deb && rm -rf /opt/workbuddy.deb /var/lib/apt/lists/*

ENV CNB_WELCOME_EXECUTE_COMMAND="chmod +x /workspace/Installer/Start.sh && bash /workspace/Installer/Start.sh"

# 触发更新标记
# 20250708
