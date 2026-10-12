#!/bin/bash
# Campagne de simulations d'équilibrage (bot). Usage : tools/balance_sim.sh "starters" "arenas" "tensions" seeds [modificateurs]
# Exemple : tools/balance_sim.sh "mossback ashblade" "fractured_plain" "tension_0 tension_1" 3
cd "$(dirname "$0")/.."
STARTERS="${1:-mossback ashblade glimmerwing}"
ARENAS="${2:-fractured_plain}"
TENSIONS="${3:-tension_0}"
SEEDS="${4:-2}"
MODS="${5:-}"
OUT="${TMPDIR:-/tmp}/rift_hunters_balance.txt"
: > "$OUT"
run_one() {
	local log
	log=$(timeout 900 godot --headless --fixed-fps 60 --path . res://tests/smoke/autoplay.tscn -- --starter="$1" --arena="$2" \
		--difficulty="$3" --seed="$4" ${MODS:+--modifiers=$MODS} 2>&1)
	local errors
	errors=$(echo "$log" | grep -c "SCRIPT ERROR")
	echo "$log" | grep "^RESULT|" | sed "s/$/|$errors/"
}
export -f run_one
export MODS
for s in $STARTERS; do for a in $ARENAS; do for t in $TENSIONS; do for seed in $(seq 1 "$SEEDS"); do
	echo "$s $a $t $seed"
done; done; done; done | xargs -P "${JOBS:-4}" -n 4 bash -c 'run_one "$@"' _ >> "$OUT"
echo "starter|arène|tension|victoire|temps|niveau|éliminations|durée boss|PV boss restants|dégâts subis|erreurs"
sort "$OUT" | sed 's/^RESULT|//'
awk -F'|' '{n++; v+=$5; e+=$12} END {printf "\nParties : %d, victoires : %d (%.0f %%), erreurs de script : %d\n", n, v, 100*v/n, e}' "$OUT"
