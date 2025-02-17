package main

import (
	"fmt"
)

type State string

const (
	BoiledWater  State = "BoiledWater"
	CoffeeBeans  State = "CoffeeBeans"
	CoffeeInPot  State = "CoffeeInPot"
	Cup          State = "Cup"
	Filter       State = "Filter"
	GroundCoffee State = "GroundCoffee"
	Payment      State = "Payment"
	Pending      State = "Pending"
	Sent         State = "Sent"
	Water        State = "Water"
)

type StateVector map[State]bool

func initialState() StateVector {
	return StateVector{
		BoiledWater:  false,
		CoffeeBeans:  true,
		CoffeeInPot:  false,
		Cup:          true,
		Filter:       true,
		GroundCoffee: false,
		Payment:      false,
		Pending:      true,
		Sent:         false,
		Water:        true,
	}
}
func BoilWater(state StateVector) (StateVector, bool) {
	if !state[Water] {
		return state, false
	}
	if state[BoiledWater] {
		return state, false
	}
	state[Water] = false
	state[BoiledWater] = true
	return state, true
}
func BrewCoffee(state StateVector) (StateVector, bool) {
	if !state[BoiledWater] {
		return state, false
	}
	if !state[GroundCoffee] {
		return state, false
	}
	if !state[Filter] {
		return state, false
	}
	if state[CoffeeInPot] {
		return state, false
	}
	state[BoiledWater] = false
	state[GroundCoffee] = false
	state[Filter] = false
	state[CoffeeInPot] = true
	return state, true
}
func Credit(state StateVector) (StateVector, bool) {
	if !state[Sent] {
		return state, false
	}
	if state[Payment] {
		return state, false
	}
	state[Sent] = false
	state[Payment] = true
	return state, true
}
func GrindBeans(state StateVector) (StateVector, bool) {
	if !state[CoffeeBeans] {
		return state, false
	}
	if state[GroundCoffee] {
		return state, false
	}
	state[CoffeeBeans] = false
	state[GroundCoffee] = true
	return state, true
}
func PourCoffee(state StateVector) (StateVector, bool) {
	if !state[CoffeeInPot] {
		return state, false
	}
	if !state[Cup] {
		return state, false
	}
	if !state[Payment] {
		return state, false
	}
	state[CoffeeInPot] = false
	state[Cup] = false
	state[Payment] = true
	return state, true
}
func Send(state StateVector) (StateVector, bool) {
	if !state[Pending] {
		return state, false
	}
	if state[Sent] {
		return state, false
	}
	state[Pending] = false
	state[Sent] = true
	return state, true
}

// executeProcess runs the transition list repeatedly until no more transitions are possible
// NOTE: This is a naive implementation provided for illustrative purposes
func executeProcess(state StateVector, transitions map[string]func(StateVector) (StateVector, bool)) StateVector {
	i := 0
	ranOne := false
	for {
		for action, transition := range transitions {
			out, ok := transition(state)
			if ok {
				i++

				fmt.Printf("%v: %s\n", i, action)
				state = out
				ranOne = true
				break
			}
		}
		if !ranOne {
			break
		}
		ranOne = false
	}
	return state
}

func main() {
	state := initialState()
	transitions := map[string]func(StateVector) (StateVector, bool){
		"BoilWater":  BoilWater,
		"BrewCoffee": BrewCoffee,
		"Credit":     Credit,
		"GrindBeans": GrindBeans,
		"PourCoffee": PourCoffee,
		"Send":       Send,
	}
	finalState := executeProcess(state, transitions)
	fmt.Println("Final State:", finalState)
}
