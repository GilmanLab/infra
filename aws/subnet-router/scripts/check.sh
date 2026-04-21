#!/usr/bin/env bash
set -euo pipefail

TF_DATA_DIR="$(mktemp -d)"
trap 'rm -rf "$TF_DATA_DIR"' EXIT
export TF_DATA_DIR

tofu fmt -check -recursive
tofu init -backend=false -input=false
tofu validate
tofu test
