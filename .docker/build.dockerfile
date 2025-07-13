# .ide/Dockerfile
FROM docker.cnb.cool/set/file/dockerimages/desktop:basement
RUN apt-mark hold tzdata
RUN apt update && apt upgrade -y && rm -rf /var/lib/apt/lists/*

#安装组件
ENV NVARCH x86_64

ENV NVIDIA_REQUIRE_CUDA "cuda>=12.2 brand=tesla,driver>=470,driver<471 brand=unknown,driver>=470,driver<471 brand=nvidia,driver>=470,driver<471 brand=nvidiartx,driver>=470,driver<471 brand=geforce,driver>=470,driver<471 brand=geforcertx,driver>=470,driver<471 brand=quadro,driver>=470,driver<471 brand=quadrortx,driver>=470,driver<471 brand=titan,driver>=470,driver<471 brand=titanrtx,driver>=470,driver<471 brand=tesla,driver>=525,driver<526 brand=unknown,driver>=525,driver<526 brand=nvidia,driver>=525,driver<526 brand=nvidiartx,driver>=525,driver<526 brand=geforce,driver>=525,driver<526 brand=geforcertx,driver>=525,driver<526 brand=quadro,driver>=525,driver<526 brand=quadrortx,driver>=525,driver<526 brand=titan,driver>=525,driver<526 brand=titanrtx,driver>=525,driver<526"
ENV NV_CUDA_CUDART_VERSION 12.2.140-1
ENV NV_CUDA_COMPAT_PACKAGE cuda-compat-12-2
RUN apt-get update && apt-get install -y --no-install-recommends \
    gnupg2 curl ca-certificates && \
    curl -fsSLO https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/cuda-keyring_1.1-1_all.deb && \
    dpkg -i cuda-keyring_1.1-1_all.deb && \
    rm -rf /var/lib/apt/lists/* && \
    echo 'deb [signed-by=/usr/share/keyrings/cuda-archive-keyring.gpg] https://developer.download.nvidia.com/compute/cuda/repos/debian11/x86_64/ /' > /etc/apt/sources.list.d/cuda-debian12-x86_64.list
ENV CUDA_VERSION 12.2.2
RUN apt-get update && apt-get install -y --no-install-recommends \
    cuda-cudart-12-2=${NV_CUDA_CUDART_VERSION} \
    ${NV_CUDA_COMPAT_PACKAGE} \
    && rm -rf /var/lib/apt/lists/*
RUN echo "/usr/local/nvidia/lib" >> /etc/ld.so.conf.d/nvidia.conf \
    && echo "/usr/local/nvidia/lib64" >> /etc/ld.so.conf.d/nvidia.conf
ENV PATH /usr/local/nvidia/bin:/usr/local/cuda/bin:${PATH}
ENV LD_LIBRARY_PATH /usr/local/nvidia/lib:/usr/local/nvidia/lib64
ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES compute,utility
#runningtime
ENV NV_CUDA_LIB_VERSION 12.2.2-1

ENV NV_NVTX_VERSION 12.2.140-1
ENV NV_LIBNPP_VERSION 12.2.1.4-1
ENV NV_LIBNPP_PACKAGE libnpp-12-2=${NV_LIBNPP_VERSION}
ENV NV_LIBCUSPARSE_VERSION 12.1.2.141-1

ENV NV_LIBCUBLAS_PACKAGE_NAME libcublas-12-2
ENV NV_LIBCUBLAS_VERSION 12.2.5.6-1
ENV NV_LIBCUBLAS_PACKAGE ${NV_LIBCUBLAS_PACKAGE_NAME}=${NV_LIBCUBLAS_VERSION}

ENV NV_LIBNCCL_PACKAGE_NAME libnccl2
ENV NV_LIBNCCL_PACKAGE_VERSION 2.19.3-1
ENV NCCL_VERSION 2.19.3-1
ENV NV_LIBNCCL_PACKAGE ${NV_LIBNCCL_PACKAGE_NAME}=${NV_LIBNCCL_PACKAGE_VERSION}+cuda12.2

RUN apt-get update && apt-get install -y --no-install-recommends \
    cuda-libraries-12-2=${NV_CUDA_LIB_VERSION} \
    ${NV_LIBNPP_PACKAGE} \
    cuda-nvtx-12-2=${NV_NVTX_VERSION} \
    libcusparse-12-2=${NV_LIBCUSPARSE_VERSION} \
    ${NV_LIBCUBLAS_PACKAGE} \
    && rm -rf /var/lib/apt/lists/*
#    ${NV_LIBNCCL_PACKAGE} \

RUN apt-mark hold ${NV_LIBCUBLAS_PACKAGE_NAME} 
#${NV_LIBNCCL_PACKAGE_NAME}
# COPY entrypoint.d/ /opt/nvidia/entrypoint.d/
# COPY nvidia_entrypoint.sh /opt/nvidia/
# ENV NVIDIA_PRODUCT_NAME="CUDA"
# ENTRYPOINT ["/opt/nvidia/nvidia_entrypoint.sh"]

#devel
ENV NV_CUDA_LIB_VERSION="12.2.2-1"

ENV NV_CUDA_CUDART_DEV_VERSION 12.2.140-1
ENV NV_NVML_DEV_VERSION 12.2.140-1
ENV NV_LIBCUSPARSE_DEV_VERSION 12.1.2.141-1
ENV NV_LIBNPP_DEV_VERSION 12.2.1.4-1
ENV NV_LIBNPP_DEV_PACKAGE libnpp-dev-12-2=${NV_LIBNPP_DEV_VERSION}

ENV NV_LIBCUBLAS_DEV_VERSION 12.2.5.6-1
ENV NV_LIBCUBLAS_DEV_PACKAGE_NAME libcublas-dev-12-2
ENV NV_LIBCUBLAS_DEV_PACKAGE ${NV_LIBCUBLAS_DEV_PACKAGE_NAME}=${NV_LIBCUBLAS_DEV_VERSION}

ENV NV_CUDA_NSIGHT_COMPUTE_VERSION 12.2.2-1
ENV NV_CUDA_NSIGHT_COMPUTE_DEV_PACKAGE cuda-nsight-compute-12-2=${NV_CUDA_NSIGHT_COMPUTE_VERSION}

ENV NV_NVPROF_VERSION 12.2.142-1
ENV NV_NVPROF_DEV_PACKAGE cuda-nvprof-12-2=${NV_NVPROF_VERSION}

ENV NV_LIBNCCL_DEV_PACKAGE_NAME libnccl-dev
ENV NV_LIBNCCL_DEV_PACKAGE_VERSION 2.19.3-1
ENV NCCL_VERSION 2.19.3-1
ENV NV_LIBNCCL_DEV_PACKAGE ${NV_LIBNCCL_DEV_PACKAGE_NAME}=${NV_LIBNCCL_DEV_PACKAGE_VERSION}+cuda12.2

RUN apt-get update && apt-get install -y --no-install-recommends \
    cuda-cudart-dev-12-2=${NV_CUDA_CUDART_DEV_VERSION} \
    cuda-command-line-tools-12-2=${NV_CUDA_LIB_VERSION} \
    cuda-minimal-build-12-2=${NV_CUDA_LIB_VERSION} \
    cuda-libraries-dev-12-2=${NV_CUDA_LIB_VERSION} \
    cuda-nvml-dev-12-2=${NV_NVML_DEV_VERSION} \
    ${NV_NVPROF_DEV_PACKAGE} \
    ${NV_LIBNPP_DEV_PACKAGE} \
    libcusparse-dev-12-2=${NV_LIBCUSPARSE_DEV_VERSION} \
    ${NV_LIBCUBLAS_DEV_PACKAGE} \
    ${NV_CUDA_NSIGHT_COMPUTE_DEV_PACKAGE} \
    && rm -rf /var/lib/apt/lists/*

    #${NV_LIBNCCL_DEV_PACKAGE} \
    ##${NV_LIBNCCL_DEV_PACKAGE_NAME}
RUN apt-mark hold ${NV_LIBCUBLAS_DEV_PACKAGE_NAME}
# ${NV_LIBNCCL_DEV_PACKAGE_NAME}
ENV LIBRARY_PATH /usr/local/cuda/lib64/stubs
RUN apt update && apt install -y sudo gnupg2 zip lsb-release bash-completion iputils-ping mesa-utils python3 python3-pip \
python3-numpy tmux build-essential software-properties-common terminator fonts-wqy-zenhei ffmpeg \
dbus-x11 pulseaudio

RUN apt install -y --no-install-recommends libxau6 libxdmcp6 libxcb1 libxext6 libx11-6 \
        libglvnd0 libgl1 libglx0 libegl1 libgles2 \
        libglvnd-dev libgl1-mesa-dev libegl1-mesa-dev libgles2-mesa-dev vulkan-tools
RUN mkdir -p /usr/share/glvnd/egl_vendor.d/ && mkdir -p /etc/vulkan/icd.d/ && echo -e '{\n"file_format_version" : "1.0.0",\n"ICD": {\n"library_path": "libEGL_nvidia.so.0"\n}\n}' > /usr/share/glvnd/egl_vendor.d/10_nvidia.json
RUN VULKAN_API_VERSION=$(dpkg -s libvulkan1 | grep -oP 'Version: [0-9|\.]+' | grep -oP '[0-9]+(\.[0-9]+)(\.[0-9]+)')
RUN echo -e '{\n"file_format_version" : "1.0.0",\n"ICD": {\n"library_path": "libGLX_nvidia.so.0",\n"api_version" : "'${VULKAN_API_VERSION}'"\n}\n}' > /etc/vulkan/icd.d/nvidia_icd.json

#virtualGL
RUN wget -q -O- https://packagecloud.io/dcommander/virtualgl/gpgkey | \
    gpg --dearmor >/etc/apt/trusted.gpg.d/VirtualGL.gpg && \
    wget https://raw.githubusercontent.com/VirtualGL/repo/main/VirtualGL.list -O /etc/apt/sources.list.d/VirtualGL.list && \
    apt update && apt install -y virtualgl 
   
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