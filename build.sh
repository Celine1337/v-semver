#!/usr/bin/env bash
# Compile v-semver with V.
set -euo pipefail
cd "$(dirname "$0")"
export TC="$HOME/.local/toolchains"
export PATH="$TC/v/v:$PATH"
command -v v >/dev/null 2>&1 || { echo "FATAL: v not found"; exit 1; }
mkdir -p bin
v -o bin/v-semver src/main.v
echo "built bin/v-semver"