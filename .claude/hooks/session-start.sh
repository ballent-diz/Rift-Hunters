#!/bin/bash
# Installe les outils nécessaires au projet dans les sessions cloud Claude Code :
# - Godot 4.3 (headless) pour valider le projet et lancer les tests
# - gdtoolkit (gdlint / gdformat) pour le lint du GDScript
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

GODOT_VERSION="4.3-stable"
GODOT_DIR="/opt/godot"
GODOT_BIN="$GODOT_DIR/Godot_v${GODOT_VERSION}_linux.x86_64"

if [ ! -x "$GODOT_BIN" ]; then
  mkdir -p "$GODOT_DIR"
  tmp_zip="$(mktemp --suffix=.zip)"
  curl -sSL --retry 4 -o "$tmp_zip" \
    "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip"
  unzip -o -q "$tmp_zip" -d "$GODOT_DIR"
  rm -f "$tmp_zip"
  chmod +x "$GODOT_BIN"
fi
ln -sf "$GODOT_BIN" /usr/local/bin/godot

if ! command -v gdlint >/dev/null 2>&1; then
  pip install --quiet "gdtoolkit==4.*"
fi

godot --headless --version >/dev/null
