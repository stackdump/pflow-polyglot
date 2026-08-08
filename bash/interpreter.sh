#!/usr/bin/env bash
# Interpreter form: the net is runtime data (ARROWS, GUARDS) and a scheduler
# searches for an enabled transition. See FORMS.md; output must match
# parity/trace.golden.
#
# Arcs are encoded "<kind>:<name>><kind>:<name>" where kind is P (place) or
# T (transition), so the node type is explicit rather than inferred — the same
# distinction the typed languages get from a Node sum type.
set -uo pipefail

TRANSITIONS=(BoilWater GrindBeans BrewCoffee PourCoffee Send Credit)

# SCHEDULE is the scheduler's candidate order: every transition, sorted by name
# under the C locale (FORMS.md specifies ASCII order). This is what implements
# the canonical scheduling policy — fire the enabled transition whose name is
# lexicographically least. The order TRANSITIONS is written in is therefore not
# load-bearing, but do not drop the sort on that basis: only 90 of the 720
# possible orders produce parity/trace.golden.
mapfile -t SCHEDULE < <(printf '%s\n' "${TRANSITIONS[@]}" | LC_ALL=C sort)

ARROWS=(
	"P:Water>T:BoilWater"
	"T:BoilWater>P:BoiledWater"
	"P:CoffeeBeans>T:GrindBeans"
	"T:GrindBeans>P:GroundCoffee"
	"P:BoiledWater>T:BrewCoffee"
	"P:GroundCoffee>T:BrewCoffee"
	"P:Filter>T:BrewCoffee"
	"T:BrewCoffee>P:CoffeeInPot"
	"P:CoffeeInPot>T:PourCoffee"
	"P:Cup>T:PourCoffee"
	"P:Pending>T:Send"
	"T:Send>P:Sent"
	"P:Sent>T:Credit"
	"T:Credit>P:Payment"
)

# A guard "T:<transition>>P:<place>" requires the place to be marked without
# consuming it. The direction matches model.json's inhibit arc.
GUARDS=(
	"T:PourCoffee>P:Payment"
)

declare -A MARKED=(
	[Water]=1
	[CoffeeBeans]=1
	[Filter]=1
	[Cup]=1
	[Pending]=1
)

# render prints the marking: marked places, sorted, comma-joined.
render() {
	for place in "${!MARKED[@]}"; do
		[[ ${MARKED[$place]} == 1 ]] && echo "$place"
	done | LC_ALL=C sort | paste -sd,
}

is_marked() {
	[[ ${MARKED[$1]:-0} == 1 ]]
}

guard_fails() {
	local transition=$1 guard from to
	for guard in "${GUARDS[@]}"; do
		from=${guard%%>*}
		to=${guard##*>}
		if [[ $from == "T:$transition" ]] && ! is_marked "${to#P:}"; then
			return 0
		fi
	done
	return 1
}

# prepare_transition sets PLACES_TO_REMOVE / PLACES_TO_ADD and returns 0 if the
# transition is enabled. Nothing is mutated here.
PLACES_TO_REMOVE=()
PLACES_TO_ADD=()
prepare_transition() {
	local transition=$1 arrow from to
	PLACES_TO_REMOVE=()
	PLACES_TO_ADD=()

	guard_fails "$transition" && return 1

	for arrow in "${ARROWS[@]}"; do
		from=${arrow%%>*}
		to=${arrow##*>}
		if [[ $from == P:* && $to == "T:$transition" ]]; then
			is_marked "${from#P:}" || return 1
			PLACES_TO_REMOVE+=("${from#P:}")
		fi
		if [[ $from == "T:$transition" && $to == P:* ]]; then
			# The net is 1-safe: firing into a marked place is not enabled.
			is_marked "${to#P:}" && return 1
			PLACES_TO_ADD+=("${to#P:}")
		fi
	done
	return 0
}

execute_transition() {
	local place
	prepare_transition "$1" || return 1
	for place in ${PLACES_TO_REMOVE+"${PLACES_TO_REMOVE[@]}"}; do
		MARKED[$place]=0
	done
	for place in ${PLACES_TO_ADD+"${PLACES_TO_ADD[@]}"}; do
		MARKED[$place]=1
	done
	return 0
}

# execute_process fires the enabled transition that sorts first, until none is
# enabled.
execute_process() {
	local step=0 transition fired
	while true; do
		fired=false
		for transition in "${SCHEDULE[@]}"; do
			if execute_transition "$transition"; then
				step=$((step + 1))
				printf 'Step #%d: %s => %s\n' "$step" "$transition" "$(render)"
				fired=true
				break
			fi
		done
		$fired || break
	done
}

execute_process
