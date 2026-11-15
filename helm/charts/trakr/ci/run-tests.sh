#!/bin/bash
# Renders the TrakR chart, checks topic provisioning, and runs the Connect pipeline tests.
set -euo pipefail

root="$(cd "$(dirname "$0")/../../../.." && pwd)"
chart="${root}/helm/charts/trakr"
dev_values="${chart}/values-dev.yaml"
work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

helm dependency build "${chart}" >/dev/null

render() {
  local release="$1"
  local dest="$2"
  shift 2
  helm template "${release}" "${chart}" \
    --values "${chart}/values.yaml" \
    "$@" >"${dest}"
}

extract_block() {
  local file="$1"
  local key="$2"
  local dest="$3"
  python3 - "$file" "$key" "$dest" <<'PY'
import sys
path, key, dest = sys.argv[1:]
lines = open(path).read().splitlines()
start = None
for i, line in enumerate(lines):
    if line.strip() == key:
        start = i + 1
        break
if start is None:
    sys.exit(f"did not find {key}")
while start < len(lines) and lines[start].strip() == "":
    start += 1
if start >= len(lines):
    sys.exit(f"{key} was empty")
prefix = len(lines[start]) - len(lines[start].lstrip(" "))
body = []
for line in lines[start:]:
    if line.strip() == "":
        body.append("")
        continue
    indent = len(line) - len(line.lstrip(" "))
    if indent < prefix:
        break
    body.append(line[prefix:])
open(dest, "w").write("\n".join(body).rstrip() + "\n")
PY
}

echo "==> render release trakr"
render trakr "${work}/trakr.yaml"
echo "==> render release dev"
render dev "${work}/dev-release.yaml"
echo "==> render adsb pipeline"
render trakr "${work}/adsb.yaml" --values "${dev_values}"

python3 - "${work}/trakr.yaml" "${work}/dev-release.yaml" "${work}/adsb.yaml" <<'PY'
import sys
trakr, dev, adsb = (open(p).read() for p in sys.argv[1:])

def require(text, needle, label):
    if needle not in text:
        sys.exit(f"{label}: missing {needle!r}")

require(trakr, "name: provision-topics", "init container")
require(trakr, "image: docker.redpanda.com/redpandadata/redpanda:v26.2.6", "rpk image")
require(trakr, "name: trakr-topics", "topic configmap")
require(trakr, 'name: trakr-topics', "init volume")
require(dev, "name: dev-trakr-topics", "release fullname")
require(trakr, 'provision_topic "adsb.basestation" "3" "1"', "default topic")
require(adsb, "partitioner: murmur2_hash", "partitioner")
require(adsb, 'key: ${! meta("kafka_key").or("") }', "record key")
require(adsb, "idempotent_write: true", "idempotent producer")
require(adsb, "max_in_flight_requests: 1", "ordered produce")
require(adsb, "acks: all", "acks")
require(adsb, "allow_auto_topic_creation: true", "auto create")
require(adsb, "$fields.index(4)", "icao field")
require(adsb, 're_match("^[0-9A-F]{6}$")', "icao check")
require(adsb, "meta kafka_key = if $valid", "icao metadata")
require(adsb, "switch:", "output switch")
require(adsb, 'meta("dead_letter") == ""', "main topic gate")
require(adsb, 'topic: "adsb.basestation"', "normalized topic")
require(adsb, 'topic: "adsb.basestation.dlq"', "dead letter topic")
if "kafka_key" in trakr.split("redpanda-connect.yaml:")[1].split("kind:")[0]:
    # The placeholder pipeline is in the base render. The topic script also
    # has no kafka_key. Search only the connect config block above.
    pass
placeholder = trakr.split("redpanda-connect.yaml: |", 1)[1].split("\n---", 1)[0]
if "kafka_key" in placeholder or "murmur2_hash" in placeholder:
    sys.exit("placeholder pipeline should not publish ADS-B records")
if "trakr.dev/topics-checksum:" not in adsb:
    sys.exit("topics checksum annotation missing")
print("render assertions passed")
PY

echo "==> checksum changes when a topic changes"
render trakr "${work}/topics-a.yaml"
cat >"${work}/topics-overlay.yaml" <<'EOF'
connect:
  topics:
    items:
      - name: adsb.basestation
        partitions: 6
        replicationFactor: 1
        config: {}
EOF
render trakr "${work}/topics-b.yaml" --values "${work}/topics-overlay.yaml"
python3 - "${work}/topics-a.yaml" "${work}/topics-b.yaml" <<'PY'
import re, sys
def checksum(path):
    text = open(path).read()
    found = re.findall(r"trakr.dev/topics-checksum:\s*['\"]?([0-9a-f]{64})['\"]?", text)
    if not found:
        sys.exit(f"no topics checksum in {path}")
    return found[0]
a, b = checksum(sys.argv[1]), checksum(sys.argv[2])
if a == b:
    sys.exit("topics checksum did not change")
print("checksum assertion passed")
PY

expect_fail() {
  local label="$1"
  shift
  if helm template trakr "${chart}" --values "${chart}/values.yaml" "$@" >"${work}/fail.out" 2>"${work}/fail.err"; then
    echo "${label}: helm template succeeded" >&2
    exit 1
  fi
  if ! grep -q "$label" "${work}/fail.err"; then
    echo "${label}: unexpected error" >&2
    cat "${work}/fail.err" >&2
    exit 1
  fi
}

echo "==> reject replication above the broker count"
cat >"${work}/rf.yaml" <<'EOF'
connect:
  topics:
    items:
      - name: adsb.basestation
        partitions: 3
        replicationFactor: 3
        config: {}
EOF
expect_fail "exceeds redpanda.statefulset.replicas" --values "${work}/rf.yaml"

echo "==> reject an even replication factor"
cat >"${work}/even.yaml" <<'EOF'
connect:
  topics:
    items:
      - name: adsb.basestation
        partitions: 3
        replicationFactor: 2
        config: {}
EOF
expect_fail "positive odd number" --values "${work}/even.yaml"

echo "==> reject a topic that ingestion does not list"
cat >"${work}/missing.yaml" <<'EOF'
connect:
  adsb:
    enabled: true
  topics:
    items:
      - name: other.topic
        partitions: 1
        replicationFactor: 1
        config: {}
EOF
expect_fail "is not listed in connect.topics.items" --values "${work}/missing.yaml"

echo "==> reject a dead-letter topic that ingestion does not list"
cat >"${work}/missing-dlq.yaml" <<'EOF'
connect:
  adsb:
    enabled: true
  topics:
    enabled: true
    items:
      - name: adsb.basestation
        partitions: 3
        replicationFactor: 1
        config: {}
EOF
expect_fail "deadLetterTopic" --values "${work}/missing-dlq.yaml"

echo "==> provisioning script"
extract_block "${work}/trakr.yaml" "provision.sh: |" "${work}/provision.sh"
bash -n "${work}/provision.sh"

cat >"${work}/topics-config.yaml" <<'EOF'
connect:
  topics:
    items:
      - name: adsb.basestation
        partitions: 3
        replicationFactor: 1
        config:
          retention.ms: "604800000"
EOF
render trakr "${work}/with-config.yaml" --values "${work}/topics-config.yaml"
extract_block "${work}/with-config.yaml" "provision.sh: |" "${work}/provision-config.sh"

run_provision() {
  local script="$1"
  local mode="$2"
  local log="$3"
  local bin="${work}/bin"
  mkdir -p "${bin}"
  cat >"${bin}/rpk" <<'PY'
#!/usr/bin/env python3
import os, sys
args = sys.argv[1:]
log = os.environ["RPK_LOG"]
counter = os.environ["RPK_COUNTER"]
parts_file = os.environ["RPK_PARTITIONS_FILE"]
with open(log, "a") as fh:
    fh.write(" ".join(args) + "\n")
if args[:2] == ["topic", "list"]:
    fails = int(os.environ.get("RPK_LIST_FAILS", "0"))
    n = int(open(counter).read() or "0")
    open(counter, "w").write(str(n + 1))
    sys.exit(0 if n >= fails else 1)
if args[:2] == ["topic", "describe"]:
    parts = open(parts_file).read().strip() or os.environ.get("RPK_PARTITIONS", "3")
    name = args[2]
    sys.stdout.write(f"SUMMARY\n=======\nNAME        {name}\nPARTITIONS  {parts}\nREPLICAS    1\n")
    sys.exit(0)
sys.exit(0)
PY
  chmod +x "${bin}/rpk"
  echo 0 >"${work}/counter"
  echo "${RPK_PARTITIONS:-3}" >"${work}/parts"
  PATH="${bin}:${PATH}" \
    RPK_LOG="${log}" \
    RPK_COUNTER="${work}/counter" \
    RPK_PARTITIONS_FILE="${work}/parts" \
    RPK_MODE="${mode}" \
    RPK_LIST_FAILS="${RPK_LIST_FAILS:-0}" \
    TOPIC_WAIT_INTERVAL=0 \
    TOPIC_WAIT_ATTEMPTS="${TOPIC_WAIT_ATTEMPTS:-5}" \
    bash "${script}"
}

: >"${work}/rpk.log"
RPK_PARTITIONS=3 RPK_LIST_FAILS=2 run_provision "${work}/provision.sh" exists "${work}/rpk.log"
python3 - "${work}/rpk.log" <<'PY'
import sys
log = open(sys.argv[1]).read().strip().splitlines()
lists = [line for line in log if line.startswith("topic list")]
if len(lists) < 3:
    sys.exit(f"expected broker retries, got {log}")
creates = [line for line in log if line.startswith("topic create")]
if len(creates) != 1 or "--if-not-exists" not in creates[0] or "--partitions 3" not in creates[0] or "--replicas 1" not in creates[0]:
    sys.exit(f"unexpected create: {creates}")
if any(line.startswith("topic add-partitions") for line in log):
    sys.exit("added partitions when the count already matched")
if any("brokers=trakr-redpanda:9093" not in line for line in log):
    sys.exit(f"broker flag missing: {log}")
print("existing topic assertion passed")
PY

: >"${work}/rpk.log"
echo 1 >"${work}/parts"
RPK_PARTITIONS=1 run_provision "${work}/provision.sh" exists "${work}/rpk.log"
python3 - "${work}/rpk.log" <<'PY'
import sys
log = open(sys.argv[1]).read().strip().splitlines()
added = [line for line in log if line.startswith("topic add-partitions")]
if len(added) != 1 or "--num 2" not in added[0]:
    sys.exit(f"expected to add 2 partitions, got {added}")
print("add partitions assertion passed")
PY

: >"${work}/rpk.log"
echo 5 >"${work}/parts"
if ! RPK_PARTITIONS=5 run_provision "${work}/provision.sh" exists "${work}/rpk.log" >"${work}/shrink.out" 2>"${work}/shrink.err"; then
  echo "shrinking partitions failed the script" >&2
  cat "${work}/shrink.err" >&2
  exit 1
fi
if ! grep -q "leaving it above requested 3" "${work}/shrink.err"; then
  echo "missing shrink warning" >&2
  cat "${work}/shrink.err" >&2
  exit 1
fi
if grep -q "topic add-partitions" "${work}/rpk.log"; then
  echo "refused to shrink, but still added partitions" >&2
  exit 1
fi

: >"${work}/rpk.log"
echo 3 >"${work}/parts"
run_provision "${work}/provision-config.sh" exists "${work}/rpk.log"
python3 - "${work}/rpk.log" <<'PY'
import sys
log = open(sys.argv[1]).read().strip().splitlines()
creates = [line for line in log if line.startswith("topic create")]
alters = [line for line in log if line.startswith("topic alter-config")]
if not creates or "--topic-config retention.ms=604800000" not in creates[0]:
    sys.exit(f"create did not carry retention: {creates}")
if len(alters) != 1 or "--no-confirm" not in alters[0] or "--set retention.ms=604800000" not in alters[0]:
    sys.exit(f"alter-config missing: {alters}")
print("topic config assertion passed")
PY

echo "==> connect pipeline"
connect_bin="${CONNECT_BIN:-}"
if [[ -z "${connect_bin}" ]]; then
  version="4.115.1"
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  arch="$(uname -m)"
  case "${arch}" in
    x86_64) arch=amd64 ;;
    aarch64|arm64) arch=arm64 ;;
  esac
  tarball="${work}/connect.tar.gz"
  url="https://github.com/redpanda-data/connect/releases/download/v${version}/redpanda-connect_${version}_${os}_${arch}.tar.gz"
  curl -fsSL "${url}" -o "${tarball}"
  tar -xzf "${tarball}" -C "${work}"
  connect_bin="${work}/redpanda-connect"
  chmod +x "${connect_bin}"
fi
extract_block "${work}/adsb.yaml" "redpanda-connect.yaml: |" "${work}/connect.yaml"
cp "${chart}/ci/adsb_pipeline_test.yaml" "${work}/connect_benthos_test.yaml"
"${connect_bin}" test "${work}/connect.yaml"

echo "trakr chart tests passed"
