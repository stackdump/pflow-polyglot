#!/usr/bin/env bash
# Contract form: the net is a public entry-point surface. There is no scheduler
# and no schedule — each transition either fires and appends to the event log,
# or refuses with a NotEnabled message on stderr. The caller decides the order.
#
# This mirrors solidity/contract.sol, where enablement is enforced by `require`
# in a modifier and the event log is the trace.
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
EVENTS=()

# marking is the contract's view function: marked places, sorted, comma-joined.
marking() {
	for place in "${!MARKED[@]}"; do
		[[ ${MARKED[$place]} == 1 ]] && echo "$place"
	done | LC_ALL=C sort | paste -sd,
}

# require is the enablement check every entry point runs first. Arguments are
# tagged so one function can express all three clauses:
#   in:<place>  must be marked and is consumed
#   out:<place> must be clear and is produced
#   req:<place> must be marked and is not consumed (a guard)
require() {
	local name=$1 arg place
	shift
	for arg in "$@"; do
		place=${arg#*:}
		case $arg in
		in:* | req:*)
			if [[ ${MARKED[$place]:-0} != 1 ]]; then
				echo "NotEnabled: $name: $place not marked" >&2
				return 1
			fi
			;;
		out:*)
			if [[ ${MARKED[$place]:-0} == 1 ]]; then
				echo "NotEnabled: $name: output $place already marked" >&2
				return 1
			fi
			;;
		esac
	done
	return 0
}

# fire applies an entry point atomically: all checks, then all effects.
fire() {
	local name=$1 arg place
	shift
	require "$name" "$@" || return 1
	for arg in "$@"; do
		place=${arg#*:}
		case $arg in
		in:*) MARKED[$place]=0 ;;
		out:*) MARKED[$place]=1 ;;
		esac
	done
	EVENTS+=("$name")
	return 0
}

boilWater() { fire BoilWater in:Water out:BoiledWater; }
grindBeans() { fire GrindBeans in:CoffeeBeans out:GroundCoffee; }
brewCoffee() { fire BrewCoffee in:BoiledWater in:GroundCoffee in:Filter out:CoffeeInPot; }
send() { fire Send in:Pending out:Sent; }
credit() { fire Credit in:Sent out:Payment; }
# Guarded on Payment, which it checks but does not consume.
pourCoffee() { fire PourCoffee req:Payment in:CoffeeInPot in:Cup; }

# The driver is the caller, not the machine. Calling these in any other order
# refuses rather than corrupting the marking.
CALLS=(
	"BoilWater:boilWater"
	"GrindBeans:grindBeans"
	"BrewCoffee:brewCoffee"
	"Send:send"
	"Credit:credit"
	"PourCoffee:pourCoffee"
)

step=0
for entry in "${CALLS[@]}"; do
	name=${entry%%:*}
	fn=${entry##*:}
	if "$fn" 2>/dev/null; then
		step=$((step + 1))
		printf 'Step #%d: %s => %s\n' "$step" "$name" "$(marking)"
	fi
done
