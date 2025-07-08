# .ide/Dockerfile
FROM docker.cnb.cool/set/file/dockerimages/desktop:basement
RUN apt-mark hold tzdata
RUN apt update && apt upgrade -y || true
#安装npm
RUN apt install -y -o APT::Install-Recommends=true npm

#安装PHP
RUN apt install -y -o APT::Install-Recommends=true php

#安装JDK
RUN apt install -y -o APT::Install-Recommends=true openjdk-17-jdk
RUN wget https://download.java.net/java/GA/jdk24.0.1/24a58e0e276943138bf3e963e6291ac2/9/GPL/openjdk-24.0.1_linux-x64_bin.tar.gz -O /opt/openjdk24.0.1.tar.gz && tar -zxvf /opt/openjdk24.0.1.tar.gz
#RUN 安装其他JDK?


#安装.net core
RUN wget https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb -O packages-microsoft-prod.deb && dpkg -i packages-microsoft-prod.deb && rm packages-microsoft-prod.deb
RUN apt-get update && apt-get install -y dotnet-sdk-8.0 dotnet-sdk-9.0

#安装golang
RUN wget https://golang.google.cn/dl/go1.24.2.linux-amd64.tar.gz -O /opt/go1.24.2.linux-amd64.tar.gz && rm -rf /usr/local/go && tar -C /usr/local -xzf /opt/go1.24.2.linux-amd64.tar.gz && rm -rf /opt/go1.24.2.linux-amd64.tar.gz

#安装ruby
RUN apt-get install -y -o APT::Install-Recommends=true ruby-full

#安装mysql(mariadb)
RUN apt install -y -o APT::Install-Recommends=true mariadb-server

#安装Redis
RUN apt install -y -o APT::Install-Recommends=true redis

#安装memcached
RUN apt install -y -o APT::Install-Recommends=true memcached

#安装其他软件
RUN wget https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_x86_64.deb -O /opt/WeChatLinux_x86_64.deb && apt install -y /opt/WeChatLinux_x86_64.deb && rm -rf /opt/WeChatLinux_x86_64.deb
RUN wget https://dldir1.qq.com/qqfile/qq/QQNT/Linux/QQ_3.2.16_250401_amd64_01.deb -O /opt/QQ_3.2.16_250401_amd64_01.deb && apt install -y /opt/QQ_3.2.16_250401_amd64_01.deb && rm -rf  /opt/QQ_3.2.16_250401_amd64_01.deb
RUN wget "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64" -O /opt/vscode.deb && apt install -y /opt/vscode.deb && rm -rf /opt/vscode.deb
RUN wget https://dbeaver.io/files/dbeaver-ce_latest_amd64.deb -O /opt/dbeaver.deb && apt install -y /opt/dbeaver.deb && rm -rf  /opt/dbeaver.deb

#安装CrossOver
RUN wget https://media.codeweavers.com/pub/crossover/cxlinux/demo/crossover_25.0.0-1.deb -O /opt/crossover_25.0.0-1.deb && apt install -y /opt/crossover_25.0.0-1.deb && rm -rf /opt/crossover_25.0.0-1.deb

#其他构建
RUN cd /opt/ && git clone https://cnb.cool/set/File/idea.git && chmod +x /opt/idea/Installer.sh && bash /opt/idea/Installer.sh && rm -rf /opt/idea 

ENV CNB_WELCOME_EXECUTE_COMMAND="chmod +x /workspace/Installer/Start.sh && bash /workspace/Installer/Start.sh"

# 触发更新标记
# 20250708