###############################
# Dockerfile to build xmrwallet
###############################
FROM ubuntu:18.04
MAINTAINER miner2049er@women-at-work.org

ENV NDK=android-ndk-r16b
ENV NDK_FILE=${NDK}-linux-x86_64.zip
ENV NDK_SUM=bcdea4f5353773b2ffa85b5a9a2ae35544ce88ec5b507301d8cf6a76b765d901

# prepare ubuntu environment
RUN apt-get update \
 && apt-get --no-install-recommends --yes install \
    ca-certificates \
    cmake \
    g++ \
    make \
    pkg-config \
    graphviz \
    doxygen \
    git \
    curl \
    libtool-bin \
    autoconf \
    build-essential cmake tofrodos \
    wget unzip python

# install android ndk
RUN mkdir /opt/android \
 && cd /opt/android \
 && wget https://dl.google.com/android/repository/${NDK_FILE} \
 && echo "${NDK_SUM}  ${NDK_FILE}" > /tmp/ndk_sum_signed \
 && sha256sum -c /tmp/ndk_sum_signed \
 && unzip "${NDK_FILE}" \
 && rm -rf "${NDK_FILE}"

# prepare standalone toolchain
RUN cd /opt/android \
 && /opt/android/${NDK}/build/tools/make_standalone_toolchain.py \
    --api 21 --stl=libc++ --arch arm --install-dir /opt/android/tool/arm \
 && /opt/android/${NDK}/build/tools/make_standalone_toolchain.py \
    --api 21 --stl=libc++ --arch arm64 --install-dir /opt/android/tool/arm64 \
 && /opt/android/${NDK}/build/tools/make_standalone_toolchain.py \
    --api 21 --stl=libc++ --arch x86 --install-dir /opt/android/tool/x86 \
 && /opt/android/${NDK}/build/tools/make_standalone_toolchain.py \
    --api 21 --stl=libc++ --arch x86_64 --install-dir /opt/android/tool/x86_64

# prepare reproduceable build container
ADD build-artifacts.sh /usr/local/bin/build-artifacts.sh
ENTRYPOINT ["/usr/local/bin/build-artifacts.sh"]
