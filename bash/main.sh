#!/bin/bash

states=(
	"Water:1"
	"BoiledWater:0"
	"CoffeeBeans:1"
	"GroundCoffee:0"
	"Filter:1"
	"CoffeeInPot:0"
	"Pending:1"
	"Sent:0"
	"Payment:0"
	"Cup:1"
)

actions=(
	"BoilWater"
	"GrindBeans"
	"BrewCoffee"
	"PourCoffee"
	"Send"
	"Credit"
)

arrows=(
	"Water > BoilWater"
	"BoilWater > BoiledWater"
	"CoffeeBeans > GrindBeans"
	"GrindBeans > GroundCoffee"
	"BoiledWater > BrewCoffee"
	"GroundCoffee > BrewCoffee"
	"Filter > BrewCoffee"
	"BrewCoffee > CoffeeInPot"
	"CoffeeInPot > PourCoffee"
	"Cup > PourCoffee"
	"Pending > Send"
	"Send > Sent"
	"Sent > Credit"
	"Credit > Payment"
)

guards=(
	"Payment > PourCoffee"
)

# Print the current state as a set
function print_state() {
	local output="{"
	for state in "${states[@]}"; do
		IFS=":" read -r name value <<<"$state"
		if [[ $value == "1" ]]; then
			output+=" $name,"
		fi
	done
	output="${output%,} }"
	echo "$output"
}

# Check if the element is present in the current state
function has_state() {
	for state in "${states[@]}"; do
		IFS=":" read -r name value <<<"$state"
		if [[ $name == "$1" && $value == "1" ]]; then
			return 0
		fi
	done
	return 1
}

# Set the state of a given element
function set_state() {
	for i in "${!states[@]}"; do
		IFS=":" read -r name value <<<"${states[$i]}"
		if [[ $name == "$1" ]]; then
			states[$i]="$name:$2"
		fi
	done
	return 0
}

function guard_fails() {
	for guard in "${guards[@]}"; do
		local from to
		IFS=" > " read -r from to <<<"$guard"
		if [[ "$from" == "$1" ]]; then
			if has_state "$to"; then
				return 0
			fi
		fi
		if [[ "$to" == "$1" ]]; then
			if ! has_state "$from"; then
				return 0
			fi
		fi

	done
	return 1
}

# Transform the state based on the action
function transform() {
	if guard_fails "$1"; then
		return 1
	fi

	local arrow

	for arrow in "${arrows[@]}"; do
		IFS=" > " read -r from to <<<"$arrow"
		if [[ "$from" == "$1" ]]; then # action -> state
			if has_state "$to"; then
				return 1 # Invalid output
			else
				set_state $to 1
			fi
		fi
		if [[ $to == "$1" ]]; then # state -> action
			if has_state "$from"; then
				set_state "$from" 0
			else
				return 1 # Insufficient input
			fi
		fi
	done
	return 0
}

# Check if the action can be performed based on the current state
function can_transform() {
	if guard_fails "$1"; then
		return 1
	fi

	local arrow
	for arrow in "${arrows[@]}"; do
		IFS=" > " read -r from to <<<"$arrow"
		if [[ $from == "$1" ]]; then # action -> state
			if has_state "$to"; then
				return 1 # Invalid output
			fi
		fi
		if [[ $to == "$1" ]]; then # state -> action
			if ! has_state "$from"; then
				return 1 # Insufficient input
			fi
		fi
	done
}

# Main function - runs the process by executing the actions
# for the current state until no more actions are possible
function main() {
	local step=1
	echo "step #0: Initial state"
	print_state
	while true; do
		local transformed=false
		for action in "${actions[@]}"; do
			if can_transform "$action"; then
				transform "$action"
				echo "step #$step: $($action)"
				transformed=true
				step=$((step + 1))
				break
			fi
		done
		if ! $transformed; then
			break
		else
			print_state
		fi
	done
}

function BoilWater {
	echo "Boiling Water"
}

function GrindBeans {
	echo "Grinding Beans"
}

function BrewCoffee {
	echo "Brewing Coffee"
}

function PourCoffee {
	echo "Pouring Coffee"
}

function Send {
	echo "Sending Payment"
}

function Credit {
	echo "Crediting Payment"
}

main
