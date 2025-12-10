#!/usr/bin/env bash
set -e

echo "=== Running ZooKeeper ZK-1208 experiment ===" >&2

# -------------------------------------------------
# Resolve paths (portable)
# -------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

T2C_DIR="$ROOT_DIR/T2C"
SYSTEM_DIR="$ROOT_DIR/zookeeper"
T2C_CONF="$T2C_DIR/conf/samples/zk-3.4.11.properties"

LOGFILE="$ROOT_DIR/run_experiments.log"

# Redirect noisy output to log file
exec > >(tee -a "$LOGFILE") 2>&1

echo "Project root: $ROOT_DIR"
echo "T2C_CONF: $T2C_CONF"
echo "SYSTEM_DIR: $SYSTEM_DIR"

# -------------------------------------------------
# Uncomment specified_test_class_list in config
# -------------------------------------------------
echo "Updating specified_test_class_list in config..."

# -------------------------------------------------
# Offline build & validate templates
# -------------------------------------------------
cd "$T2C_DIR"
./run_engine.sh build "$T2C_CONF"

cd "$SYSTEM_DIR" && mv templates_out templates_in 2>/dev/null || echo 'templates_out missing'

cd "$T2C_DIR"
./run_engine.sh validate "$T2C_CONF"

cd "$SYSTEM_DIR" && mv templates_in templates_in_old 2>/dev/null || echo 'templates_in missing'

# -------------------------------------------------
# Copy validated templates
# -------------------------------------------------
mkdir -p "$SYSTEM_DIR/templates_in"
cp -r "$T2C_DIR/inv_verify_output/verified_inv_dir/"* "$SYSTEM_DIR/templates_in/" || true

# -------------------------------------------------
# Prepare patch path (portable)
# -------------------------------------------------
PATCH_PATH="$T2C_DIR/conf/samples/patches/install_zk-1208.patch"

sed -i "s|^patch_path=.*|patch_path=$PATCH_PATH|" "$T2C_CONF"

# -------------------------------------------------
# Patch & retrofit
# -------------------------------------------------
cd "$T2C_DIR"
./run_engine.sh patch "$T2C_CONF" zookeeper
./run_engine.sh recover_tests "$T2C_CONF"
./run_engine.sh retrofit "$T2C_CONF"

# -------------------------------------------------
# Prepare ZooKeeper config
# -------------------------------------------------
cp "$T2C_DIR/experiments/detection/zookeeper/ZK-1208/zoo.cfg" "$SYSTEM_DIR/conf/"

# Ensure dataDir is correct
grep -q "^dataDir=" "$SYSTEM_DIR/conf/zoo.cfg" \
  && sed -i "s|^dataDir=.*|dataDir=$SYSTEM_DIR|" "$SYSTEM_DIR/conf/zoo.cfg" \
  || echo "dataDir=$SYSTEM_DIR" >> "$SYSTEM_DIR/conf/zoo.cfg"

# -------------------------------------------------
# Start ZooKeeper & trigger bug
# -------------------------------------------------
cd "$SYSTEM_DIR"
./bin/zkServer.sh start

"$T2C_DIR/experiments/detection/zookeeper/ZK-1208/ZK-1208.sh"

# -------------------------------------------------
# Show result in Jupyter (not only in log file)
# -------------------------------------------------
echo "=== EXPERIMENT FINISHED ===" >&2
echo "Showing important results from t2c.prod.log" >&2

if [ -f "$SYSTEM_DIR/t2c.prod.log" ]; then
  echo ""
  echo "----- Log Preview / Result -----" >&2
  grep -E 'SuccessMap|FailMap' "$SYSTEM_DIR/t2c.prod.log" || echo "No SuccessMap/FailMap entries found" >&2
  echo "--------------------------------" >&2
else
  echo "Log file not found: $SYSTEM_DIR/t2c.prod.log" >&2
fi
