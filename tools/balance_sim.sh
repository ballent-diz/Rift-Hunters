#!/bin/bash
# Campagne de simulations d'équilibrage (bot). Usage : tools/balance_sim.sh "starters" "arenas" "difficultés" seeds [modificateurs]
# Exemple : tools/balance_sim.sh "mossback ashblade" "fractured_plain" "normal nightmare" 3
# Variables : JOBS (parallélisme), META=veteran|expert (bonus d'arbre typiques), TEAM=mossback,glimmerwing (compagnons)
cd "$(dirname "$0")/.."
STARTERS="${1:-mossback ashblade glimmerwing}"
ARENAS="${2:-fractured_plain}"
DIFFICULTIES="${3:-normal}"
SEEDS="${4:-2}"
MODS="${5:-}"
META="${META:-}"
OUT="${TMPDIR:-/tmp}/rift_hunters_balance.txt"
: > "$OUT"
run_one() {
	local log
	log=$(timeout ${SIM_TIMEOUT:-900} godot --headless --fixed-fps 60 --path . res://tests/smoke/autoplay.tscn -- --starter="$1" --arena="$2" \
		--difficulty="$3" --seed="$4" ${MODS:+--modifiers=$MODS} ${META:+--meta=$META} ${TEAM:+--team=$TEAM} 2>&1)
	local errors
	errors=$(echo "$log" | grep -c "SCRIPT ERROR")
	echo "$log" | grep "^RESULT|" | sed "s/$/|$errors/"
}
export -f run_one
export MODS META TEAM
for s in $STARTERS; do for a in $ARENAS; do for t in $DIFFICULTIES; do for seed in $(seq 1 "$SEEDS"); do
	echo "$s $a $t $seed"
done; done; done; done | xargs -P "${JOBS:-4}" -n 4 bash -c 'run_one "$@"' _ >> "$OUT"
echo "starter|arène|difficulté|victoire|temps|niveau|éliminations|durée boss|PV boss restants|dégâts subis|erreurs"
sort "$OUT" | sed 's/^RESULT|//'
awk -F'|' '{n++; v+=$5; e+=$12} END {printf "\nParties : %d, victoires : %d (%.0f %%), erreurs de script : %d\n", n, v, 100*v/n, e}' "$OUT"
