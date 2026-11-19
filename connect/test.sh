#!/bin/sh
# Runs the ADS-B pipeline unit tests against connect/adsb.yaml.
set -eu

root="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
version="4.115.1"
connect_bin="${CONNECT_BIN:-}"

if [ -z "$connect_bin" ]; then
  work="$(mktemp -d)"
  trap 'rm -rf "$work"' EXIT
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  arch="$(uname -m)"
  case "$arch" in
    x86_64) arch=amd64 ;;
    aarch64|arm64) arch=arm64 ;;
  esac
  tarball="${work}/connect.tar.gz"
  url="https://github.com/redpanda-data/connect/releases/download/v${version}/redpanda-connect_${version}_${os}_${arch}.tar.gz"
  curl -fsSL "$url" -o "$tarball"
  tar -xzf "$tarball" -C "$work"
  connect_bin="${work}/redpanda-connect"
  chmod +x "$connect_bin"
fi

export ADSB_ADDRESS="${ADSB_ADDRESS:-trakr-simulator:30003}"
export ADSB_BROKER="${ADSB_BROKER:-trakr-redpanda:9093}"
export ADSB_TOPIC="${ADSB_TOPIC:-adsb.basestation}"
export ADSB_DEAD_LETTER_TOPIC="${ADSB_DEAD_LETTER_TOPIC:-adsb.basestation.dlq}"

"$connect_bin" test "${root}/adsb.yaml"
