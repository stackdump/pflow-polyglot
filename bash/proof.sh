#!/usr/bin/env bash
# Proof form: the net is a claim about every reachable marking, checked by an
# exhaustive model-check before a single trace line is printed. See FORMS.md;
# output must match parity/trace.golden.
#
# The marking is a multiset — a count per place, not a set — and enablement is
# plain P/T semantics with no `capacity: 1` clause. Startup verifies:
#
#  1. 1-safety is structural: no reachable marking holds two tokens anywhere,
#     even without the capacity clause. This licenses the set representation
#     every other form uses.
#  2. The outcome is confluent: every reachable deadlock is exactly {Payment}.
#
# A violation aborts with the offending marking on stderr — which fails the
# parity gate, since a program that dies cannot print six lines.
#
# A marking travels as a string of counts joined with ":" in PLACES order —
# bash arrays don't nest, so the BFS queue and seen-set both work on that key.
set -uo pipefail

PLACES=(Water BoiledWater CoffeeBeans GroundCoffee Filter
	CoffeeInPot Pending Sent Payment Cup)

declare -A INDEX=()
for i in "${!PLACES[@]}"; do
	INDEX[${PLACES[$i]}]=$i
done

# The net. SCHEDULE below sorts these by name for the trace loop. Inputs
# consumed, outputs produced, guards read but not consumed.
TRANSITIONS=(BoilWater GrindBeans BrewCoffee PourCoffee Send Credit)

# SCHEDULE is the scheduler's candidate order: every transition, sorted by name
# under the C locale (FORMS.md specifies ASCII order). This is what implements
# the canonical scheduling policy — fire the enabled transition whose name is
# lexicographically least. The order TRANSITIONS is written in is therefore not
# load-bearing, but do not drop the sort on that basis: only 90 of the 720
# possible orders produce parity/trace.golden.
mapfile -t SCHEDULE < <(printf '%s\n' "${TRANSITIONS[@]}" | LC_ALL=C sort)

declare -A INPUTS=(
	[BoilWater]="Water"
	[GrindBeans]="CoffeeBeans"
	[BrewCoffee]="BoiledWater GroundCoffee Filter"
	[PourCoffee]="CoffeeInPot Cup"
	[Send]="Pending"
	[Credit]="Sent"
)

declare -A OUTPUTS=(
	[BoilWater]="BoiledWater"
	[GrindBeans]="GroundCoffee"
	[BrewCoffee]="CoffeeInPot"
	[PourCoffee]=""
	[Send]="Sent"
	[Credit]="Payment"
)

declare -A GUARDS=(
	[BoilWater]=""
	[GrindBeans]=""
	[BrewCoffee]=""
	[PourCoffee]="Payment"
	[Send]=""
	[Credit]=""
)

initial_marking() {
	local -a counts=()
	local place
	for place in "${PLACES[@]}"; do
		case $place in
		Water | CoffeeBeans | Filter | Cup | Pending) counts+=(1) ;;
		*) counts+=(0) ;;
		esac
	done
	local IFS=:
	echo "${counts[*]}"
}

# enabled <marking-key> <transition>: plain P/T enablement — inputs and guards
# marked. Deliberately no "outputs clear" clause; that the clause is never
# needed is check 1.
enabled() {
	local -a counts
	IFS=: read -r -a counts <<<"$1"
	local place
	for place in ${INPUTS[$2]} ${GUARDS[$2]}; do
		[[ ${counts[${INDEX[$place]}]} -ge 1 ]] || return 1
	done
	return 0
}

# fire <marking-key> <transition>: echoes the successor marking key. The caller
# has already checked enablement.
fire() {
	local -a counts
	IFS=: read -r -a counts <<<"$1"
	local place
	for place in ${INPUTS[$2]}; do
		counts[${INDEX[$place]}]=$((counts[${INDEX[$place]}] - 1))
	done
	for place in ${OUTPUTS[$2]}; do
		counts[${INDEX[$place]}]=$((counts[${INDEX[$place]}] + 1))
	done
	local IFS=:
	echo "${counts[*]}"
}

# render <marking-key>: marked places, sorted, comma-joined.
render() {
	local -a counts
	IFS=: read -r -a counts <<<"$1"
	local i
	for i in "${!PLACES[@]}"; do
		[[ ${counts[$i]} -ge 1 ]] && echo "${PLACES[$i]}"
	done | LC_ALL=C sort | paste -sd,
}

# verify explores the full reachable state space by breadth-first search and
# checks both claims. An unsafe marking fails immediately, so the explored
# space is a subset of {0,1}^10 and the search needs no bound to terminate.
verify() {
	local initial
	initial=$(initial_marking)
	local -A seen=(["$initial"]=1)
	local -a frontier=("$initial") deadlocks=()

	while [[ ${#frontier[@]} -gt 0 ]]; do
		local marking=${frontier[0]}
		frontier=("${frontier[@]:1}")

		local -a counts
		IFS=: read -r -a counts <<<"$marking"
		local count
		for count in "${counts[@]}"; do
			if [[ $count -gt 1 ]]; then
				echo "proof failed: 1-safety violated: reachable marking $marking" >&2
				return 1
			fi
		done

		local fired=0 transition next
		for transition in "${SCHEDULE[@]}"; do
			enabled "$marking" "$transition" || continue
			fired=1
			next=$(fire "$marking" "$transition")
			if [[ -z ${seen[$next]:-} ]]; then
				seen[$next]=1
				frontier+=("$next")
			fi
		done
		[[ $fired -eq 0 ]] && deadlocks+=("$marking")
	done

	if [[ ${#deadlocks[@]} -ne 1 || $(render "${deadlocks[0]}") != "Payment" ]]; then
		local got=""
		local d
		for d in "${deadlocks[@]}"; do
			got+=" {$(render "$d")}"
		done
		echo "proof failed: deadlock not unique {Payment}: got$got" >&2
		return 1
	fi
	return 0
}

# The interpreter form's scheduler, running on a net the model-check has
# already verified.
execute_process() {
	local marking step=0
	marking=$(initial_marking)
	while true; do
		local fired=0 transition
		for transition in "${SCHEDULE[@]}"; do
			enabled "$marking" "$transition" || continue
			marking=$(fire "$marking" "$transition")
			step=$((step + 1))
			echo "Step #$step: $transition => $(render "$marking")"
			fired=1
			break
		done
		[[ $fired -eq 0 ]] && return 0
	done
}

verify || exit 1
execute_process
