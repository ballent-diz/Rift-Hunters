#!/bin/bash
# Lance les vérifications du projet. Usage : tools/run_tests.sh [all|unit|scripts|persistence|assets|smoke|lint]
# Les sorties sont écrites dans des fichiers puis affichées (évite les blocages de tampon).
set -uo pipefail
cd "$(dirname "$0")/.."
MODE="${1:-all}"
GODOT="${GODOT:-godot}"
LOG_DIR="${TMPDIR:-/tmp}/rift_hunters_tests"
mkdir -p "$LOG_DIR"
STATUS=0

run_step() {
	local name="$1"; shift
	local log="$LOG_DIR/$name.log"
	timeout "${STEP_TIMEOUT:-600}" "$@" > "$log" 2>&1
	local code=$?
	grep -v "^Godot Engine" "$log" | grep -vE "ObjectDB instances leaked|resources still in use|at: (cleanup|clear) " || true
	if [ $code -ne 0 ]; then
		echo "❌ $name (code $code)"
		STATUS=1
	else
		echo "✅ $name"
	fi
}

# Toujours réimporter : enregistre les nouvelles classes (class_name) et les traductions.
timeout 300 "$GODOT" --headless --import --path . > "$LOG_DIR/import.log" 2>&1

if [[ "$MODE" == "all" || "$MODE" == "scripts" ]]; then
	run_step scripts "$GODOT" --headless --path . res://tools/check_scripts.tscn
fi
if [[ "$MODE" == "all" || "$MODE" == "unit" ]]; then
	run_step unit "$GODOT" --headless --path . res://tests/run_tests.tscn
fi
if [[ "$MODE" == "all" || "$MODE" == "persistence" ]]; then
	# Deux processus distincts : écriture, fermeture, puis relecture au redémarrage.
	run_step persistence_write "$GODOT" --headless --path . res://tests/smoke/persistence.tscn -- --phase=write
	run_step persistence_read "$GODOT" --headless --path . res://tests/smoke/persistence.tscn -- --phase=read
fi
if [[ "$MODE" == "all" || "$MODE" == "assets" ]]; then
	run_step assets "$GODOT" --headless --path . res://tools/validate_assets.tscn
fi
if [[ "$MODE" == "all" || "$MODE" == "smoke" ]]; then
	run_step smoke "$GODOT" --headless --fixed-fps 60 --path . res://tests/smoke/autoplay.tscn -- --starter=ashblade --seed=1
fi
if [[ "$MODE" == "all" || "$MODE" == "lint" ]]; then
	if command -v gdlint > /dev/null; then
		run_step lint gdlint src tests tools
	fi
fi
exit $STATUS
