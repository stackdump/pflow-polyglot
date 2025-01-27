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

// CoffeeMachineState is a slice of States
type CoffeeMachineState []State

// Helper Function to Check if a State Exists in the Current State
func contains(state CoffeeMachineState, target State) bool {
	for _, s := range state {
		if s == target {
			return true
		}
	}
	return false
}

// Helper Function to Remove a State from the Current State
func remove(state CoffeeMachineState, target State) CoffeeMachineState {
	newState := make(CoffeeMachineState, 0)
	for _, s := range state {
		if s != target {
			newState = append(newState, s)
		}
	}
	return newState
}

// Transition Functions
func boilWater(state CoffeeMachineState) CoffeeMachineState {
	if contains(state, Water) && !contains(state, BoiledWater) {
		state = remove(state, Water)
		state = append(state, BoiledWater)
	}
	return state
}

func grindBeans(state CoffeeMachineState) CoffeeMachineState {
	if contains(state, CoffeeBeans) && !contains(state, GroundCoffee) {
		state = remove(state, CoffeeBeans)
		state = append(state, GroundCoffee)
	}
	return state
}

func brewCoffee(state CoffeeMachineState) CoffeeMachineState {
	if contains(state, BoiledWater) && contains(state, GroundCoffee) && contains(state, Filter) && !contains(state, CoffeeInPot) {
		state = remove(state, BoiledWater)
		state = remove(state, GroundCoffee)
		state = remove(state, Filter)
		state = append(state, CoffeeInPot)
	}
	return state
}

func pourCoffee(state CoffeeMachineState) CoffeeMachineState {
	if contains(state, CoffeeInPot) && contains(state, Cup) {
		state = remove(state, CoffeeInPot)
		state = remove(state, Cup)
		state = append(state, Pending)
	}
	return state
}

func send(state CoffeeMachineState) CoffeeMachineState {
	if contains(state, Pending) {
		state = remove(state, Pending)
		state = append(state, Sent)
	}
	return state
}

func credit(state CoffeeMachineState) CoffeeMachineState {
	if contains(state, Sent) {
		state = remove(state, Sent)
		state = append(state, Payment)
	}
	return state
}

// Define the Initial State
func initialState() CoffeeMachineState {
	return CoffeeMachineState{
		Water, CoffeeBeans, Filter, Cup, Pending,
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
