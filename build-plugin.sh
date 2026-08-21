#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${1:-dist}"
MANIFEST="$ROOT_DIR/.claude-plugin/plugin.json"

if [[ ! -f "$MANIFEST" ]]; then
  echo "Missing plugin manifest: $MANIFEST" >&2
  exit 1
fi

for required_file in "$ROOT_DIR/skills/explain-file/SKILL.md" "$ROOT_DIR/skills/explain-selection/SKILL.md" "$ROOT_DIR/README.md"; do
  if [[ ! -f "$required_file" ]]; then
    echo "Missing plugin file: $required_file" >&2
    exit 1
  fi
done

readarray -t metadata < <(python - "$MANIFEST" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as manifest_file:
    manifest = json.load(manifest_file)

name = manifest.get("name")
version = manifest.get("version")
if not name or not version:
    raise SystemExit("The plugin manifest must define non-empty name and version fields.")
print(name)
print(version)
PY
)

NAME="${metadata[0]}"
VERSION="${metadata[1]}"
OUTPUT_PATH="$ROOT_DIR/$OUTPUT_DIR"
ZIP_PATH="$OUTPUT_PATH/$NAME-$VERSION.zip"
STAGING_PATH="$(mktemp -d)"
trap 'rm -rf "$STAGING_PATH"' EXIT

mkdir -p "$OUTPUT_PATH"
cp -R "$ROOT_DIR/.claude-plugin" "$STAGING_PATH/"
cp -R "$ROOT_DIR/skills" "$STAGING_PATH/"
cp "$ROOT_DIR/README.md" "$STAGING_PATH/"
rm -f "$ZIP_PATH"

(cd "$STAGING_PATH" && zip -qr "$ZIP_PATH" .)
echo "Built $ZIP_PATH"