#!/usr/bin/env bash

echo "Running experiments for ZooKeeper ZK-1208 detection"

set -e

T2C_CONF="$HOME/T2C/conf/samples/zk-3.4.11.properties"
SYSTEM_DIR="$HOME/zookeeper"

# --- Offline build & validate templates ---
cd ~/T2C
./run_engine.sh build $T2C_CONF
cd $SYSTEM_DIR && mv templates_out templates_in || echo 'templates_out missing'
cd ~/T2C
./run_engine.sh validate $T2C_CONF
cd $SYSTEM_DIR && mv templates_in templates_in_old || echo 'templates_in missing'

# --- Copy validated templates for runtime ---
mkdir -p $SYSTEM_DIR/templates_in
cp -r ~/T2C/inv_verify_output/verified_inv_dir/* $SYSTEM_DIR/templates_in/

# --- Prepare ZK-1208 detection ---
PATCH_PATH="$HOME/T2C/conf/samples/patches/install_zk-1208.patch"
sed -i "s|patch_path=.*|patch_path=$PATCH_PATH|" $T2C_CONF

cd ~/T2C
./run_engine.sh patch $T2C_CONF zookeeper
./run_engine.sh recover_tests $T2C_CONF
./run_engine.sh retrofit $T2C_CONF

cp ~/T2C/experiments/detection/zookeeper/ZK-1208/zoo.cfg $SYSTEM_DIR/conf/
echo "dataDir=$SYSTEM_DIR" >> $SYSTEM_DIR/conf/zoo.cfg

# --- Start Zookeeper & trigger bug ---
cd $SYSTEM_DIR
./bin/zkServer.sh start
~/T2C/experiments/detection/zookeeper/ZK-1208/ZK-1208.sh

# --- Check logs ---
cat $SYSTEM_DIR/t2c.prod.log || echo "Log file not found"

echo """
The checking result will be printed to t2c.prod.log.
If some invariant fails and report, the log would print failed invariants such as:
"""
grep -E 'SuccessMap|FailMap' "$SYSTEM_DIR/t2c.prod.log" || echo "Log file not found"
