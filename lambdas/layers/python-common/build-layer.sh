#!/usr/bin/env bash
# Build Lambda layer using uv. Run from project root.
# Usage: ./build-layer.sh [DEST_DIR]
#   DEST_DIR defaults to lambdas/layers/ (output: DEST_DIR/python-common-layer.zip)
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST_DIR="${1:-$(dirname "$SCRIPT_DIR")}"
cd "$SCRIPT_DIR"

echo "=== Building python-common layer with uv ==="
uv lock
uv export --frozen --no-dev --no-editable -o requirements.txt
rm -rf packages python
uv pip install \
  --no-installer-metadata \
  --python-platform x86_64-manylinux2014 \
  --python 3.11 \
  --prefix packages \
  -r requirements.txt

mkdir -p python "$DEST_DIR"
cp -r packages/lib python/
zip -rX "$DEST_DIR/python-common-layer.zip" python
rm -rf packages python requirements.txt
echo "Built: $DEST_DIR/python-common-layer.zip"
