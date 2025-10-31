#!/usr/bin/env bash

echo "Setting up experimental environment"

set -e

# --- Install dependencies ---
sudo apt-get update
sudo apt-get install -y git maven ant vim openjdk-8-jdk golang-go gnuplot tmux

export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
export PATH="$JAVA_HOME/bin:$PATH"
echo export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64 >> ~/.bashrc
echo export PATH="$JAVA_HOME/bin:$PATH" >> ~/.bashrc

# --- Clone T2C repository ---
git clone https://github.com/OrderLab/T2C.git || echo 'T2C already cloned'

# --- Build T2C ---
cd T2C
./run_engine.sh compile

# --- Clone ZooKeeper ---
cd ~
git clone https://github.com/apache/zookeeper.git || echo 'ZK already cloned'
cd zookeeper && git checkout tags/release-3.4.11

# --- Patch & retrofit T2C ---
T2C_CONF="$HOME/T2C/conf/samples/zk-3.4.11.properties"
SYSTEM_DIR="$HOME/zookeeper"
sed -i "s|system_dir_path=.*|system_dir_path=$SYSTEM_DIR|" $T2C_CONF

cd ~/T2C
./run_engine.sh patch $T2C_CONF zookeeper
./run_engine.sh recover_tests $T2C_CONF
./run_engine.sh retrofit $T2C_CONF
