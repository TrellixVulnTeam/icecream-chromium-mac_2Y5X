#!/bin/sh

realpath() {
  python -c "import os; print(os.path.realpath('$1'))"
}

ICECC_CREATE_ENV="${ICECC_CREATE_ENV:-$(which icecc-create-env)}"
ICECC_ENV_DIR="${ICECC_ENV_DIR:-$HOME/.icecc-envs}"
ICECC_ENV_TEMP_DIR="${ICECC_ENV_DIR}/temp"
ICECC_LINUX_ENV_DIR="${ICECC_ENV_DIR}/linux"
ICECC_CHROMIUM_MAC_DIR="$(realpath $(dirname $0))"

mkdir -p $ICECC_LINUX_ENV_DIR
if [ ! -w $ICECC_ENV_DIR ]; then
  echo "Error: Can't write to $ICECC_ENV_DIR. Set \$ICECC_ENV_DIR to change." >&2
  exit 1
fi

if [ ! -x $ICECC_CREATE_ENV ]; then
  echo "Error: Can't execute $ICECC_CREATE_ENV. Set \$ICECC_CREATE_ENV to change." >&2
  exit 1
fi

CHROMIUM_PATH="$(realpath ${1:-$CHROMIUM_PATH})"

if [ -z "$CHROMIUM_PATH" ]; then
  echo "Usage: $0 [path-to-chromium]" >&2
  exit 1
fi

CLANG_VERSION_SCRIPT="${CHROMIUM_PATH}/tools/clang/scripts/update.py"

if [ ! -x "$CLANG_VERSION_SCRIPT" ]; then
  echo "Error: No clang version script found at $CLANG_VERSION_SCRIPT." >&2
  exit 1
fi

CLANG_VERSION=`$CLANG_VERSION_SCRIPT --print-revision`

if [ -z "$CLANG_VERSION" ]; then
  echo "Error: Couldn't determine version using $CLANG_VERSION_SCRIPT." >&2
  exit 1
fi

ENV_NAME="clang-${CLANG_VERSION}.tar.gz"
MAC_ENV_PATH="${ICECC_ENV_DIR}/${ENV_NAME}"
LINUX_ENV_PATH="${ICECC_LINUX_ENV_DIR}/${ENV_NAME}"

if [ ! -e "$MAC_ENV_PATH" ]; then
  LLVM_PATH="${CHROMIUM_PATH}/third_party/llvm-build/Release+Asserts"
  CLANG_PATH="${LLVM_PATH}/bin/clang"
  PLUGINS_PATH="${LLVM_PATH}/lib"

  if [ ! -x "$CLANG_PATH" ]; then
    echo "Error: Can't find clang executable at $CLANG_PATH." >&2
    exit 1
  fi

  mkdir -p $ICECC_ENV_TEMP_DIR
  rm -rf {$ICECC_ENV_TEMP_DIR}/*

  TEMP_ENV_FILENAME=`(cd $ICECC_ENV_TEMP_DIR && exec 5>&1 && $ICECC_CREATE_ENV --clang $CLANG_PATH 1>/dev/null)`
  if [ -z "$TEMP_ENV_FILENAME" ]; then
    echo "Error: couldn't get file name of generated file." >&2
    exit 1
  fi

  TEMP_ENV_PATH=${ICECC_ENV_TEMP_DIR}/${TEMP_ENV_FILENAME}
  if [ ! -e "$TEMP_ENV_PATH" ]; then
    echo "Error: Can't find environment created at $TEMP_ENV_PATH." >&2
    exit 1
  fi

  pushd $ICECC_ENV_TEMP_DIR
  tar xzf $TEMP_ENV_FILENAME 1>/dev/null
  mkdir -p usr/local/lib
  cp $PLUGINS_PATH/libFindBadConstructs.dylib usr/local/lib/
  cp $PLUGINS_PATH/libBlinkGCPlugin.dylib usr/local/lib/
  rm $TEMP_ENV_FILENAME
  tar czf $MAC_ENV_PATH . 1>/dev/null
  popd

  rm -rf $ICECC_ENV_TEMP_DIR
fi

if [ ! -e "$LINUX_ENV_PATH" ]; then
  ICECC_CREATE_ENV_LINUX="${ICECC_CHROMIUM_MAC_DIR}/create-icecc-env-linux.py"
  if [ ! -x "$ICECC_CREATE_ENV_LINUX" ]; then
    echo "Error: Can't execute $ICECC_CREATE_ENV_LINUX." >&2
    exit 1
  fi
  ICECC_BASE_LINUX="${ICECC_CHROMIUM_MAC_DIR}/clang-icecc-base-linux.tar.gz"
  TEMP_ENV_FILENAME=`(cd $ICECC_LINUX_ENV_DIR && $ICECC_CREATE_ENV_LINUX $ICECC_BASE_LINUX $CLANG_VERSION)`
fi

echo "Darwin17_x86_64:${MAC_ENV_PATH},x86_64:${LINUX_ENV_PATH}"
