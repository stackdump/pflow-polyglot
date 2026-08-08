#!/usr/bin/env bash
# Lambda form: each transition is a function from marking to marking, composed
# in a fixed schedule. No arrow list, no enablement search — the arcs survive
# only as control flow inside each function.
#
# Bash has no immutable values, so "pure" here means: a transition either
# applies all of its effects and returns 0, or touches nothing and returns 1.
# Every precondition is checked before any mutation.
#
# The fixed schedule is not an independent authorial choice: it is the firing
# sequence the canonical scheduling policy yields, precomputed with the search
# removed.
#
# See FORMS.md; output must match parity/trace.golden.
set -uo pipefail

declare -A MARKED=(
	[Water]=1
	[CoffeeBeans]=1
	[Filter]=1
	[Cup]=1
	[Pending]=1
)

render() {
	for place in "${!MARKED[@]}"; do
		[[ ${MARKED[$place]} == 1 ]] && echo "$place"
	done | LC_ALL=C sort | paste -sd,
}

marked() { [[ ${MARKED[$1]:-0} == 1 ]]; }
clear_place() { MARKED[$1]=0; }
set_place() { MARKED[$1]=1; }

boil_water() {
	marked Water || return 1
	marked BoiledWater && return 1
	clear_place Water
	set_place BoiledWater
}

grind_beans() {
	marked CoffeeBeans || return 1
	marked GroundCoffee && return 1
	clear_place CoffeeBeans
	set_place GroundCoffee
}

brew_coffee() {
	marked BoiledWater || return 1
	marked GroundCoffee || return 1
	marked Filter || return 1
	marked CoffeeInPot && return 1
	clear_place BoiledWater
	clear_place GroundCoffee
	clear_place Filter
	set_place CoffeeInPot
}

send() {
	marked Pending || return 1
	marked Sent && return 1
	clear_place Pending
	set_place Sent
}

credit() {
	marked Sent || return 1
	marked Payment && return 1
	clear_place Sent
	set_place Payment
}

# Carries the model's one guard: Payment must be marked, and is not consumed.
pour_coffee() {
	marked Payment || return 1
	marked CoffeeInPot || return 1
	marked Cup || return 1
	clear_place CoffeeInPot
	clear_place Cup
}

# The canonical firing order. Unlike the interpreter form, nothing here searches
# for it — it is the author's claim about the model.
SCHEDULE=(
	"BoilWater:boil_water"
	"GrindBeans:grind_beans"
	"BrewCoffee:brew_coffee"
	"Send:send"
	"Credit:credit"
	"PourCoffee:pour_coffee"
)

step=0
for entry in "${SCHEDULE[@]}"; do
	name=${entry%%:*}
	fn=${entry##*:}
	if "$fn"; then
		step=$((step + 1))
		printf 'Step #%d: %s => %s\n' "$step" "$name" "$(render)"
	fi
done
