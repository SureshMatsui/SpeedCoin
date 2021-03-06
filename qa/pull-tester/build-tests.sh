#!/bin/bash
# Param1: The prefix to mingw staging
# Param2: Path to java comparison tool
# Param3: Number of make jobs. Defaults to 1.

# Exit immediately if anything fails:
set -e
set -o xtrace

MINGWPREFIX=$1
JAVA_COMPARISON_TOOL=$2
RUN_EXPENSIVE_TESTS=$3
JOBS=${4-1}
OUT_DIR=${5-}

if [ $# -lt 2 ]; then
  echo "Usage: $0 [mingw-prefix] [java-comparison-tool] <make jobs> <save output dir>"
  exit 1
fi

DISTDIR=SpeedCoin-1.0.0

# Cross-compile for windows first (breaking the mingw/windows build is most common)
cd /home/speedcoin/Desktop/speedcoin-v1
make distdir
mkdir -p win32-build
rsync -av $DISTDIR/ win32-build/
rm -r $DISTDIR
cd win32-build

if [ $RUN_EXPENSIVE_TESTS = 1 ]; then
  ./configure --disable-silent-rules --disable-ccache --prefix=$MINGWPREFIX --host=i586-mingw32msvc --with-qt-bindir=$MINGWPREFIX/host/bin --with-qt-plugindir=$MINGWPREFIX/plugins --with-qt-incdir=$MINGWPREFIX/include --with-boost=$MINGWPREFIX --with-protoc-bindir=$MINGWPREFIX/host/bin CPPFLAGS=-I$MINGWPREFIX/include LDFLAGS=-L$MINGWPREFIX/lib --with-comparison-tool="$JAVA_COMPARISON_TOOL"
else
  ./configure --disable-silent-rules --disable-ccache --prefix=$MINGWPREFIX --host=i586-mingw32msvc --with-qt-bindir=$MINGWPREFIX/host/bin --with-qt-plugindir=$MINGWPREFIX/plugins --with-qt-incdir=$MINGWPREFIX/include --with-boost=$MINGWPREFIX --with-protoc-bindir=$MINGWPREFIX/host/bin CPPFLAGS=-I$MINGWPREFIX/include LDFLAGS=-L$MINGWPREFIX/lib
fi
make -j$JOBS

# And compile for Linux:
cd /home/speedcoin/Desktop/speedcoin-v1
make distdir
mkdir -p linux-build
rsync -av $DISTDIR/ linux-build/
rm -r $DISTDIR
cd linux-build
if [ $RUN_EXPENSIVE_TESTS = 1 ]; then
  ./configure --disable-silent-rules --disable-ccache --with-comparison-tool="$JAVA_COMPARISON_TOOL" --enable-comparison-tool-reorg-tests
else
  ./configure --disable-silent-rules --disable-ccache --with-comparison-tool="$JAVA_COMPARISON_TOOL"
fi
make -j$JOBS

# link interesting binaries to parent out/ directory, if it exists. Do this before
# running unit tests (we want bad binaries to be easy to find)
if [ -d "$OUT_DIR" -a -w "$OUT_DIR" ]; then
  set +e
  # Windows:
  cp /home/speedcoin/Desktop/speedcoin-v1/win32-build/src/SpeedCoind.exe $OUT_DIR/SpeedCoind.exe
  cp /home/speedcoin/Desktop/speedcoin-v1/win32-build/src/test/test_SpeedCoin.exe $OUT_DIR/test_SpeedCoin.exe
  cp /home/speedcoin/Desktop/speedcoin-v1/win32-build/src/qt/SpeedCoind-qt.exe $OUT_DIR/SpeedCoin-qt.exe
  # Linux:
  cp /home/speedcoin/Desktop/speedcoin-v1/linux-build/src/SpeedCoind $OUT_DIR/SpeedCoind
  cp /home/speedcoin/Desktop/speedcoin-v1/linux-build/src/test/test_SpeedCoin $OUT_DIR/test_SpeedCoin
  cp /home/speedcoin/Desktop/speedcoin-v1/linux-build/src/qt/SpeedCoind-qt $OUT_DIR/SpeedCoin-qt
  set -e
fi

# Run unit tests and blockchain-tester on Linux:
cd /home/speedcoin/Desktop/speedcoin-v1/linux-build
make check

# Run RPC integration test on Linux:
/home/speedcoin/Desktop/speedcoin-v1/qa/rpc-tests/wallet.sh /home/speedcoin/Desktop/speedcoin-v1/linux-build/src

if [ $RUN_EXPENSIVE_TESTS = 1 ]; then
  # Run unit tests and blockchain-tester on Windows:
  cd /home/speedcoin/Desktop/speedcoin-v1/win32-build
  make check
fi

# Clean up builds (pull-tester machine doesn't have infinite disk space)
cd /home/speedcoin/Desktop/speedcoin-v1/linux-build
make clean
cd /home/speedcoin/Desktop/speedcoin-v1/win32-build
make clean

# TODO: Fix code coverage builds on pull-tester machine
# # Test code coverage
# cd /home/speedcoin/Desktop/speedcoin-v1
# make distdir
# mv $DISTDIR linux-coverage-build
# cd linux-coverage-build
# ./configure --enable-lcov --disable-silent-rules --disable-ccache --with-comparison-tool="$JAVA_COMPARISON_TOOL"
# make -j$JOBS
# make cov
