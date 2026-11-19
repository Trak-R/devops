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
require(trakr, "name: trakr-connect-env", "connect env configmap")
require(trakr, 'ADSB_ADDRESS: "trakr-simulator:30003"', "default feed")
require(trakr, 'ADSB_BROKER: "trakr-redpanda:9093"', "default broker")
require(trakr, 'ADSB_TOPIC: "adsb.basestation"', "default topic env")
require(trakr, 'ADSB_DEAD_LETTER_TOPIC: "adsb.basestation.dlq"', "default dlq env")
require(trakr, 'ADSB_ENABLED: "false"', "adsb disabled")
require(trakr, 'image: "ghcr.io/trak-r/connect:unset"', "connect image")
require(trakr, "- /connect/entrypoint.sh", "connect entrypoint")
require(trakr, "name: trakr-connect-env", "runtime volume")
require(dev, "name: dev-connect-env", "release env configmap")
require(dev, 'ADSB_ADDRESS: "dev-trakr-simulator:30003"', "release feed")
require(adsb, 'ADSB_ENABLED: "false"', "dev feed disabled")
placeholder = trakr.split("redpanda-connect.yaml: |", 1)[1].split("\n---", 1)[0]
if "kafka_key" in placeholder or "murmur2_hash" in placeholder or "${ADSB_" in placeholder:
    sys.exit("chart config should not contain the ADS-B pipeline")
if "trakr.dev/topics-checksum:" not in adsb:
    sys.exit("topics checksum annotation missing")
if "name: trakr-api" in trakr or "name: trakr-api" in adsb:
    sys.exit("api rendered while components.api is false")
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

echo "==> api deployment"
cat >"${work}/api.yaml" <<'EOF'
components:
  api: true
api:
  image:
    repository: ghcr.io/trak-r/api
    tag: abc123
EOF
render trakr "${work}/api-render.yaml" --values "${work}/api.yaml"
python3 - "${work}/api-render.yaml" <<'PY'
import sys
text = open(sys.argv[1]).read()
docs = text.split("\n---\n")

def document(kind, name):
    matches = [doc for doc in docs if f"kind: {kind}\n" in doc and f"\n  name: {name}\n" in doc]
    if len(matches) != 1:
        sys.exit(f"expected one {kind} {name}, found {len(matches)}")
    return matches[0]

deploy = document("Deployment", "trakr-api")
service = document("Service", "trakr-api")
secret = document("Secret", "trakr-api")
for needle in (
    'image: "ghcr.io/trak-r/api:abc123"',
    "path: /health",
    "readOnlyRootFilesystem: true",
    "runAsUser: 65532",
    "mountPath: /tmp",
    "- name: DB_HOST\n              value: \"trakr-postgresql\"",
    "- name: DB_USER",
    "key: POSTGRES_USER",
    "- name: DB_PASSWORD",
    "key: POSTGRES_PASSWORD",
    "- name: DB_NAME",
    "key: POSTGRES_DB",
    "- name: SECRET_KEY",
    "key: SECRET_KEY",
    '- name: DEBUG\n              value: "false"',
    '- name: LOG_FILE\n              value: ""',
    'value: "[\\"*\\"]"',
    "name: trakr-ghcr",
):
    if needle not in deploy:
        sys.exit(f"api deployment missing {needle!r}")
if "REDIS_URL" in deploy or "celery" in deploy.lower():
    sys.exit("api deployment includes celery or redis")
init, sep, api = deploy.partition("\n      containers:\n")
if not sep or "name: migrate" not in init:
    sys.exit("api deployment is missing the migrate init container")
for needle in (
    "command:",
    "- alembic",
    "- -c",
    "- /app/apps/api/alembic.ini",
    "- upgrade",
    "- head",
):
    if needle not in init:
        sys.exit(f"migrate init container missing {needle!r}")
if "command:" in api:
    sys.exit("api container overrides the image command")
if any("trakr-redis" in doc or "\n  name: redis\n" in doc for doc in docs):
    sys.exit("redis rendered with the api")
if "port: 80" not in service or "targetPort: http" not in service:
    sys.exit("api service port is wrong")
if "SECRET_KEY:" not in secret:
    sys.exit("api secret is missing SECRET_KEY")
if any("kind: Ingress" in doc and "\n  name: trakr-api\n" in doc for doc in docs):
    sys.exit("api ingress rendered while disabled")
print("api render assertions passed")
PY

echo "==> reject the api without postgres"
cat >"${work}/api-no-postgres.yaml" <<'EOF'
components:
  api: true
  postgresql: false
api:
  image:
    tag: abc123
EOF
expect_fail "components.api requires components.postgresql" --values "${work}/api-no-postgres.yaml"

echo "==> reject the api without an image tag"
cat >"${work}/api-no-tag.yaml" <<'EOF'
components:
  api: true
EOF
expect_fail "api.image.tag is required when components.api is true" --values "${work}/api-no-tag.yaml"

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
"${root}/connect/test.sh"

echo "trakr chart tests passed"
