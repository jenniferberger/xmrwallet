#!/usr/bin/env bash

# build the dependencies with the android ndk cross toolchain
# download the files, checksum them
# configure and make to BUILD_ROOT_ARTIFACT
# this file may be used with a tagged container:
# have 3gb data and some cpu performance for this task
# docker build . -t xmr-wallet-build
# docker run -it \
#   -v $(pwd)/artifacts:/var/src/artifacts \
#   -v $(pwd)/build-artifacts.sh:/usr/local/bin/build-artifacts.sh \
#   xmr-wallet-build /bin/bash
# in-docker: time bash /usr/local/bin/build-artifacts.sh
# until it is working, then ADD this file to container and use entrypoint

set -x

BUILD_ROOT=/var/src
ARTIFACT_ROOT=${BUILD_ROOT}/artifacts

NDK=${NDK:-android-ndk-r16b}
ANDROID_NDK_ROOT=/opt/android/${NDK}
ANDROID_OPENSSL_GIT_URL=https://github.com/m2049r/android-openssl.git

BOOST_VERSION=1.58.0
# j!!!
OPENSSL_VERSION=1.0.2l
MONERO_GIT_URL=https://github.com/m2049r/monero.git
MONERO_GIT_BRANCH=remotes/origin/release-v0.12-monerujo-v1.4.7


OPENSSL_VERSION_=$(echo ${OPENSSL_VERSION}| sed 's|\.|_|g')
OPENSSL_TAR=OpenSSL_${OPENSSL_VERSION_}.tar.gz
OPENSSL_TAR_SHA256SUM=a3d3a7c03c90ba370405b2d12791598addfcafb1a77ef483c02a317a56c08485
OPENSSL_URL_BASE=https://github.com/openssl/openssl/archive
OPENSSL_URL=${OPENSSL_URL_BASE}/${OPENSSL_TAR}

BOOST_VERSION_=$(echo $BOOST_VERSION | sed 's|\.|_|g')
BOOST_DIR=boost_${BOOST_VERSION_}
BOOST_TAR=boost_${BOOST_VERSION_}.tar.gz
BOOST_TAR_SHA256SUM=a004d9b3fa95e956383693b86fce1b68805a6f71c2e68944fa813de0fb8c8102
BOOST_URL_BASE=https://sourceforge.net/projects/boost/files/boost
BOOST_URL=${BOOST_URL_BASE}/${BOOST_VERSION}/${BOOST_TAR}/download

declare -a BUILD_ARCHS=(arm arm64 x86 x86_64)
# release or debug
BUILD_TYPE=release

function die() {
  echo $@
  exit 1
}

function download() {
  mkdir -p "${BUILD_ROOT}/distfiles"
  pushd "${BUILD_ROOT}/distfiles"
  test -f "${OPENSSL_TAR}" \
    || wget "${OPENSSL_URL}" -O "${OPENSSL_TAR}" \
      || die "cannot get ${OPENSSL_URL}"
  checksum "${OPENSSL_TAR}" "${OPENSSL_TAR_SHA256SUM}"
  test -f "${BOOST_TAR}" \
    || wget "${BOOST_URL}" -O "${BOOST_TAR}" \
      || die "cannot get ${BOOST_URL}"
  checksum "${BOOST_TAR}" "${BOOST_TAR_SHA256SUM}"
  test -d android-openssl \
    && (cd android-openssl && git pull || die "android-openssl could not be updated") \
    || git clone "${ANDROID_OPENSSL_GIT_URL}" \
    || die "android-openssl could not be cloned"
  test -d monero \
    && (cd monero && git checkout master && git pull || die "monero could not be updated") \
    || git clone "${MONERO_GIT_URL}" \
    || die "monero could not be cloned"
  pushd monero
    git checkout "${MONERO_GIT_BRANCH}"
    git pull
    git submodule init \
      || die "monero submodules could not be initialized"
    git submodule update \
      || die "monero submodules could not be updated"
  popd # source
  popd
}

function checksum() {
  FILENAME="$1"
  SHA256SUM="$2"
  TMP_CHECKFILE="$(mktemp)"
  echo -n "${SHA256SUM}  ${FILENAME}" \
    > "${TMP_CHECKFILE}"
  cat ${TMP_CHECKFILE}
  sha256sum -c "${TMP_CHECKFILE}" \
    || die "checksum for ${FILENAME} not expected:" \
      " is $(sha256sum ${FILENAME}) instead of ${SHA256SUM}"
  # XX todo: should also be removed on die, irrelevant in container
  rm "${TMP_CHECKFILE}"
}

function build_openssl() {
  # Build OpenSSL
  # Best is to compile openssl from sources.
  # Copying from your phone or elsewhere (don't!) ends up in misery.

  rm -rf "${BUILD_ROOT}/android-openssl"
  pushd "${BUILD_ROOT}"
  git clone "${BUILD_ROOT}/distfiles/android-openssl"
  pushd ${BUILD_ROOT}/android-openssl
  tar xzf ${BUILD_ROOT}/distfiles/${OPENSSL_TAR} \
    || die "cannot unpack ${OPENSSL_TAR}"
  PATH="${PATH}:/opt/android/tool/arm/bin/:/opt/android/tool/arm64/bin/:/opt/android/tool/x86/bin/:/opt/android/tool/x86_64/bin" \
  ./build-all-arch.sh \
    || die "cannot build openssl"

  mkdir -p ${ARTIFACT_ROOT}/openssl/{arm,arm64,x86,x86_64}
  cp -a ./prebuilt/armeabi \
    ${ARTIFACT_ROOT}/openssl/arm/lib
  cp -a ./prebuilt/arm64-v8a \
    ${ARTIFACT_ROOT}/openssl/arm64/lib
  cp -a ./prebuilt/x86 \
    ${ARTIFACT_ROOT}/openssl/x86/lib
  cp -a ./prebuilt/x86_64 \
    ${ARTIFACT_ROOT}/openssl/x86_64/lib
  cp -aL ./openssl-OpenSSL_${OPENSSL_VERSION_}/include/openssl/ \
    ${ARTIFACT_ROOT}/openssl/include
  ln -s ${ARTIFACT_ROOT}/openssl/include \
    ${ARTIFACT_ROOT}/openssl/arm/include
  ln -s ${ARTIFACT_ROOT}/openssl/include \
    ${ARTIFACT_ROOT}/openssl/arm64/include
  ln -s ${ARTIFACT_ROOT}/openssl/include \
    ${ARTIFACT_ROOT}/openssl/x86/include
  ln -s ${ARTIFACT_ROOT}/openssl/include \
    ${ARTIFACT_ROOT}/openssl/x86_64/include
  popd # /var/src/android-openssl
  popd # /var/src
}

function install_openssl(){
  # imo not required anymore
  # XXXX
  DESTDIR=$1
  # install ARTIFACTs
  ln -sf ${ARTIFACT_ROOT}/openssl/include \
    /opt/android/tool/arm/sysroot/usr/include/openssl
  ln -sf ${ARTIFACT_ROOT}/openssl/arm/lib/*.so \
    /opt/android/tool/arm/sysroot/usr/lib

  ln -sf ${ARTIFACT_ROOT}/openssl/include \
    /opt/android/tool/arm64/sysroot/usr/include/openssl
  ln -sf ${ARTIFACT_ROOT}/openssl/arm64/lib/*.so \
    /opt/android/tool/arm64/sysroot/usr/lib

  ln -sf ${ARTIFACT_ROOT}/openssl/include \
    /opt/android/tool/x86/sysroot/usr/include/openssl
  ln -sf ${ARTIFACT_ROOT}/openssl/x86/lib/*.so \
    /opt/android/tool/x86/sysroot/usr/lib

  ln -sf ${ARTIFACT_ROOT}/openssl/include \
    /opt/android/tool/x86_64/sysroot/usr/include/openssl
  ln -sf ${ARTIFACT_ROOT}/openssl/x86_64/lib/*.so \
    /opt/android/tool/x86_64/sysroot/usr/lib64
  popd # var/src/android-openssl
}

function build_boost(){
  # Build Boost
  rm -rf "${BUILD_ROOT}/boost"
  mkdir -p "${BUILD_ROOT}/boost"
  pushd "${BUILD_ROOT}/boost"
  tar xzf "${BUILD_ROOT}/distfiles/${BOOST_TAR}" \
    || die "failed to unpack boost"
  pushd "${BOOST_DIR}"
  ./bootstrap.sh

  # Comment out using ::fgetpos; & using ::fsetpos; in cstdio.

  # XXXXX this is weird... maybe use a more recent boost version?
  sed -i backup "s|using ::fgetpos;|//using ::fgetpos;|" boost/compatibility/cpp_c_headers/cstdio
  sed -i backup "s|using ::fsetpos;|//using ::fsetpos;|" boost/compatibility/cpp_c_headers/cstdio

  # Then build & install to ${ARTIFACT_ROOT}/boost/${arch}
  for arch in "${BUILD_ARCHS[@]}"; do
    case "${arch}" in
      "arm")
        target_host=arm-linux-androideabi
        ;;
      "arm64")
        target_host=aarch64-linux-android
        xarch="armv8-a"
        sixtyfour=ON
        ;;
      "x86")
        target_host=i686-linux-android
        xarch="i686"
        sixtyfour=OFF
        ;;
      "x86_64")
        target_host=x86_64-linux-android
        xarch="x86-64"
        sixtyfour=ON
        ;;
      *)
        exit 16
        ;;
    esac
    PATH="/opt/android/tool/${arch}/${target_host}/bin:/opt/android/tool/${arch}/bin:${PATH}" \
    ./b2 --build-type=minimal link=static runtime-link=static \
      --with-chrono \
      --with-date_time \
      --with-filesystem \
      --with-program_options \
      --with-regex \
      --with-serialization \
      --with-system \
      --with-thread \
      --build-dir=android-${arch}  \
      --prefix=${ARTIFACT_ROOT}/boost/${arch}  \
      --includedir=${ARTIFACT_ROOT}/boost/include \
      toolset=clang threading=multi threadapi=pthread target-os=android \
      install
  done

  popd # BOOST_DIR
  popd # /var/src/boost
}

function install_boost(){
  # imo not required as everything is in the arch dir, if required rewrite to
  # for loop
  # XXXXX
  DESTDIR="$1"
  pushd ${BUILD_ROOT}/boost
  ln -sf ../include "${DESTDIR}/boost/arm"
  ln -sf ../include "${DESTDIR}/boost/arm64"
  ln -sf ../include "${DESTDIR}/boost/x86"
  ln -sf ../include "${DESTDIR}/boost/x86_64"
  popd # BOOST_DIR
}

function build_monero(){
  # Build Monero
  rm -rf "${BUILD_ROOT}/monero"
  pushd "${BUILD_ROOT}"
  cp -r "${BUILD_ROOT}/distfiles/monero" monero
  pushd monero
  git checkout "${MONERO_GIT_BRANCH}"

  # XXXX this is so not ok!!!!!
  sed -i backup "s|#include <unistd.h>|#include <unistd.h>\n#include <err.h>\n" \
    src/crypto/random.c

  for arch in "${BUILD_ARCHS[@]}"; do
    ldflags=""
    case "${arch}" in
      "arm")
        target_host=arm-linux-androideabi
        ldflags="-march=armv7-a -Wl,--fix-cortex-a8"
        xarch=armv7-a
        sixtyfour=OFF
        ;;
      "arm64")
        target_host=aarch64-linux-android
        xarch="armv8-a"
        sixtyfour=ON
        ;;
      "x86")
        target_host=i686-linux-android
        xarch="i686"
        sixtyfour=OFF
        ;;
      "x86_64")
        target_host=x86_64-linux-android
        xarch="x86-64"
        sixtyfour=ON
        ;;
      *)
        exit 16
        ;;
    esac
    OUTPUT_DIR="build/${BUILD_TYPE}.${arch}"
    mkdir -p "${OUTPUT_DIR}"
    pushd "${OUTPUT_DIR}"

    PATH="/opt/android/tool/${arch}/${target_host}/bin:/opt/android/tool/${arch}/bin:${PATH}" \
    CC=clang CXX=clang++ cmake \
      -D BUILD_GUI_DEPS=1 -D BUILD_TESTS=OFF \
      -D ARCH="${xarch}" -D STATIC=ON -D BUILD_64="${sixtyfour}" \
      -D CMAKE_BUILD_TYPE=${BUILD_TYPE} -D ANDROID=true \
      -D BUILD_TAG="android" -D BOOST_ROOT="${ARTIFACT_ROOT}/boost/" \
      -D BOOST_LIBRARYDIR="${ARTIFACT_ROOT}/boost/${arch}/lib" \
      -D OPENSSL_ROOT_DIR="${ARTIFACT_ROOT}/openssl/${arch}" \
      -D OPENSSL_INCLUDE_DIR="${ARTIFACT_ROOT}/openssl/${arch}/include" \
      -D OPENSSL_CRYPTO_LIBRARY="${ARTIFACT_ROOT}/openssl/${arch}/lib/${arch}/libcrypto.so" \
      -D OPENSSL_SSL_LIBRARY="${ARTIFACT_ROOT}/openssl/${arch}/lib/${arch}/libssl.so" \
      -D CMAKE_POSITION_INDEPENDENT_CODE:BOOL=true \
      ../.. \
      || die "could not configure monero"
    make wallet_api \
      || die "could not build wallet api"
    #??
    find . -path ./lib -prune -o -name '*.a' -exec cp '{}' lib \;

    TARGET_LIB_DIR="${ARTIFACT_ROOT}/monero/${arch}/lib"
    rm -rf "${TARGET_LIB_DIR}"
    mkdir -p "${TARGET_LIB_DIR}"
    cp "${OUTPUT_DIR}/lib/*.a" "${TARGET_LIB_DIR}"

    TARGET_INC_DIR="${ARTIFACT_ROOT}/monero/include"
    rm -rf "${TARGET_INC_DIR}"
    mkdir -p "${TARGET_INC_DIR}"
    cp -a ../src/wallet/api/wallet2_api.h "${TARGET_INC_DIR}"
    popd # OUTPUT_DIR
  done
  popd # monero
  popd # /var/src/monero
}

download

build_openssl
build_boost

install_openssl
install_boost

# currently failing because of a weird monero/.../random.c compile error
# err.h included but err/errx not available, when hacked cryptonote_core.cpp
# /opt/android/tool/arm/bin/../lib/gcc/arm-linux-androideabi/4.9.x/../../../../include/c++/4.9.x/__tree:1819:22: error
build_monero

