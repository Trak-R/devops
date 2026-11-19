#!/bin/sh
# Reads ADS-B settings from /connect/runtime (a mounted ConfigMap) or the
# environment, then starts the pipeline baked into this image.
set -eu

runtime="${CONNECT_RUNTIME:-/connect/runtime}"

read_var() {
  key="$1"
  file="${runtime}/${key}"
  if [ -f "$file" ]; then
    value=$(tr -d '\n' <"$file")
    export "$key=$value"
  fi
  eval "current=\${$key-}"
  if [ -z "${current}" ]; then
    echo "missing ${key}" >&2
    exit 1
  fi
}

read_var ADSB_ADDRESS
read_var ADSB_BROKER
read_var ADSB_TOPIC
read_var ADSB_DEAD_LETTER_TOPIC

enabled=""
if [ -f "${runtime}/ADSB_ENABLED" ]; then
  enabled=$(tr -d '\n' <"${runtime}/ADSB_ENABLED")
fi
config=/connect/placeholder.yaml
if [ "$enabled" = "true" ]; then
  config=/connect/adsb.yaml
fi

exec /redpanda-connect -c "$config"
