package main

import (
	"fmt"
)

// Define States as an Enum-like Type
type State string

const (
	Water        State = "Water"
	BoiledWater  State = "BoiledWater"
	CoffeeBeans  State = "CoffeeBeans"
	GroundCoffee State = "GroundCoffee"
	Filter       State = "Filter"
	CoffeeInPot  State = "CoffeeInPot"
	Pending      State = "Pending"
	Sent         State = "Sent"
	Payment      State = "Payment"
	Cup          State = "Cup"
)

// CoffeeMachineState is a map of States to bool
type CoffeeMachineState map[State]bool

// Transition Functions
func boilWater(state CoffeeMachineState) CoffeeMachineState {
	if state[Water] && !state[BoiledWater] {
		state[Water] = false
		state[BoiledWater] = true
	}
	return state
}

func grindBeans(state CoffeeMachineState) CoffeeMachineState {
	if state[CoffeeBeans] && !state[GroundCoffee] {
		state[CoffeeBeans] = false
		state[GroundCoffee] = true
	}
	return state
}

func brewCoffee(state CoffeeMachineState) CoffeeMachineState {
	if state[BoiledWater] && state[GroundCoffee] && state[Filter] && !state[CoffeeInPot] {
		state[BoiledWater] = false
		state[GroundCoffee] = false
		state[Filter] = false
		state[CoffeeInPot] = true
	}
	return state
}

func pourCoffee(state CoffeeMachineState) CoffeeMachineState {
	if state[CoffeeInPot] && state[Cup] {
		state[CoffeeInPot] = false
		state[Cup] = false
		state[Pending] = true
	}
	return state
}

func send(state CoffeeMachineState) CoffeeMachineState {
	if state[Pending] {
		state[Pending] = false
		state[Sent] = true
	}
	return state
}

func credit(state CoffeeMachineState) CoffeeMachineState {
	if state[Sent] {
		state[Sent] = false
		state[Payment] = true
	}
	return state
}

// Define the Initial State
func initialState() CoffeeMachineState {
	return CoffeeMachineState{
		Water:        true,
		CoffeeBeans:  true,
		Filter:       true,
		Cup:          true,
		Pending:      true,
		BoiledWater:  false,
		GroundCoffee: false,
		CoffeeInPot:  false,
		Sent:         false,
		Payment:      false,
	}
}

// Execute All Transitions
func executeProcess(state CoffeeMachineState, transitions []func(CoffeeMachineState) CoffeeMachineState) CoffeeMachineState {
	for _, transition := range transitions {
		state = transition(state)
	}
	return state
}

func main() {
	// Initial State
	state := initialState()

	// Define the Sequence of Transitions
	transitions := []func(CoffeeMachineState) CoffeeMachineState{
		boilWater,
		grindBeans,
		brewCoffee,
		pourCoffee,
		send,
		credit,
	}

	// Execute the Process
	finalState := executeProcess(state, transitions)

	// Print the Final State
	fmt.Println("Final State:", finalState)
}
