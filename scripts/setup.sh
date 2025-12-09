#!/usr/bin/env bash
set -e

echo "=== Setup starting ===" >&2

# -------------------------------------------------
# Resolve paths (portable, independent of where called)
# -------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

LOGFILE="$ROOT_DIR/setup.log"

# Redirect all output to log file + still show in Jupyter
exec > >(tee -a "$LOGFILE") 2>&1

echo "Project root: $ROOT_DIR"

# -------------------------------------------------
# Install dependencies
# -------------------------------------------------
sudo apt-get update
sudo apt-get install -y \
  git \
  maven \
  ant \
  vim \
  openjdk-8-jdk \
  golang-go \
  gnuplot \
  tmux

# -------------------------------------------------
# Java environment
# -------------------------------------------------
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
export PATH="$JAVA_HOME/bin:$PATH"

if ! grep -q "JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64" ~/.bashrc; then
  echo 'export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64' >> ~/.bashrc
fi

if ! grep -q 'JAVA_HOME/bin' ~/.bashrc; then
  echo 'export PATH="$JAVA_HOME/bin:$PATH"' >> ~/.bashrc
fi

# -------------------------------------------------
# Clone T2C
# -------------------------------------------------
cd "$ROOT_DIR"

if [ ! -d "T2C" ]; then
  git clone https://github.com/OrderLab/T2C.git
else
  echo "T2C already cloned"
fi

# -------------------------------------------------
# Build T2C
# -------------------------------------------------
cd "$ROOT_DIR/T2C"
./run_engine.sh compile

# -------------------------------------------------
# Clone ZooKeeper
# -------------------------------------------------
cd "$ROOT_DIR"

if [ ! -d "zookeeper" ]; then
  git clone https://github.com/apache/zookeeper.git
else
  echo "ZooKeeper already cloned"
fi

cd "$ROOT_DIR/zookeeper"
git fetch --tags
git checkout tags/release-3.4.11

# -------------------------------------------------
# Patch & retrofit T2C
# -------------------------------------------------
T2C_CONF="$ROOT_DIR/T2C/conf/samples/zk-3.4.11.properties"
SYSTEM_DIR="$ROOT_DIR/zookeeper"

echo "Using config: $T2C_CONF"
echo "System dir: $SYSTEM_DIR"

sed -i "s|system_dir_path=.*|system_dir_path=$SYSTEM_DIR|" "$T2C_CONF"

cd "$ROOT_DIR/T2C"

./run_engine.sh patch "$T2C_CONF" zookeeper
./run_engine.sh recover_tests "$T2C_CONF"
./run_engine.sh retrofit "$T2C_CONF"

echo "=== Setup finished ===" >&2
