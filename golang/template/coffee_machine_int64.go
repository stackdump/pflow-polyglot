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

type StateVector map[State]int64

func initialState() StateVector {
	return StateVector{
		BoiledWater:  0,
		CoffeeBeans:  1,
		CoffeeInPot:  0,
		Cup:          1,
		Filter:       1,
		GroundCoffee: 0,
		Payment:      0,
		Pending:      1,
		Sent:         0,
		Water:        1,
	}
}
func BoilWater(state StateVector) (StateVector, bool) {
	if state[Water] <= 0 {
		return state, false
	}
	if state[BoiledWater] > 0 {
		return state, false
	}
	state[Water] -= 1
	state[BoiledWater] += 1
	return state, true
}
func BrewCoffee(state StateVector) (StateVector, bool) {
	if state[BoiledWater] <= 0 {
		return state, false
	}
	if state[GroundCoffee] <= 0 {
		return state, false
	}
	if state[Filter] <= 0 {
		return state, false
	}
	if state[CoffeeInPot] > 0 {
		return state, false
	}
	state[BoiledWater] -= 1
	state[GroundCoffee] -= 1
	state[Filter] -= 1
	state[CoffeeInPot] += 1
	return state, true
}
func Credit(state StateVector) (StateVector, bool) {
	if state[Sent] <= 0 {
		return state, false
	}
	if state[Payment] > 0 {
		return state, false
	}
	state[Sent] -= 1
	state[Payment] += 1
	return state, true
}
func GrindBeans(state StateVector) (StateVector, bool) {
	if state[CoffeeBeans] <= 0 {
		return state, false
	}
	if state[GroundCoffee] > 0 {
		return state, false
	}
	state[CoffeeBeans] -= 1
	state[GroundCoffee] += 1
	return state, true
}
func PourCoffee(state StateVector) (StateVector, bool) {
	if state[CoffeeInPot] <= 0 {
		return state, false
	}
	if state[Cup] <= 0 {
		return state, false
	}
	if state[Payment] <= 0 {
		return state, false
	}
	state[CoffeeInPot] -= 1
	state[Cup] -= 1
	state[Payment] += 1
	return state, true
}
func Send(state StateVector) (StateVector, bool) {
	if state[Pending] <= 0 {
		return state, false
	}
	if state[Sent] > 0 {
		return state, false
	}
	state[Pending] -= 1
	state[Sent] += 1
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
