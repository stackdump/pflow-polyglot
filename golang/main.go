package main

import (
	"fmt"
)

type State string

var (
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

type Action string

var (
	BoilWater  Action = "BoilWater"
	GrindBeans Action = "GrindBeans"
	BrewCoffee Action = "BrewCoffee"
	PourCoffee Action = "PourCoffee"
	Send       Action = "Send"
	Credit     Action = "Credit"
)

type Node struct {
	Place      *State
	Transition *Action
}

type Arrow struct {
	From Node
	To   Node
}

type Guard struct {
	From Node
	To   Node
}

type StateVector map[State]int

type CoffeeMachine struct {
	State  StateVector
	Arrows []Arrow
	Guards []Guard
}

func NewCoffeeMachine() *CoffeeMachine {
	initialState := map[State]int{
		Water:       1,
		CoffeeBeans: 1,
		Filter:      1,
		Cup:         1,
		Pending:     1,
	}

	arrows := []Arrow{
		{From: Node{Place: &Water}, To: Node{Transition: &BoilWater}},
		{From: Node{Transition: &BoilWater}, To: Node{Place: &BoiledWater}},
		{From: Node{Place: &CoffeeBeans}, To: Node{Transition: &GrindBeans}},
		{From: Node{Transition: &GrindBeans}, To: Node{Place: &GroundCoffee}},
		{From: Node{Place: &BoiledWater}, To: Node{Transition: &BrewCoffee}},
		{From: Node{Place: &GroundCoffee}, To: Node{Transition: &BrewCoffee}},
		{From: Node{Place: &Filter}, To: Node{Transition: &BrewCoffee}},
		{From: Node{Transition: &BrewCoffee}, To: Node{Place: &CoffeeInPot}},
		{From: Node{Place: &CoffeeInPot}, To: Node{Transition: &PourCoffee}},
		{From: Node{Place: &Cup}, To: Node{Transition: &PourCoffee}},
		{From: Node{Place: &Pending}, To: Node{Transition: &Send}},
		{From: Node{Transition: &Send}, To: Node{Place: &Sent}},
		{From: Node{Place: &Sent}, To: Node{Transition: &Credit}},
		{From: Node{Transition: &Credit}, To: Node{Place: &Payment}},
	}

	guards := []Guard{
		{From: Node{Transition: &PourCoffee}, To: Node{Place: &Payment}},
	}

	return &CoffeeMachine{
		State:  initialState,
		Arrows: arrows,
		Guards: guards,
	}
}

func (cm *CoffeeMachine) CanExecute(state StateVector, transition Action) bool {
	canExecute, _, _ := cm.PrepareTransition(state, transition)
	return canExecute
}

func (cm *CoffeeMachine) GuardFails(state StateVector, transition Action) bool {
	for _, guard := range cm.Guards {
		if guard.From.Transition != nil && *guard.From.Transition == transition && state[*guard.To.Place] == 0 {
			return true
		}
		if guard.To.Transition != nil && *guard.To.Transition == transition && state[*guard.From.Place] > 0 {
			return true
		}
	}
	return false
}

func (cm *CoffeeMachine) PrepareTransition(state StateVector, transition Action) (bool, []State, []State) {
	var placesToRemove, placesToAdd []State

	if cm.GuardFails(state, transition) {
		return false, placesToRemove, placesToAdd
	}

	for _, arrow := range cm.Arrows {
		if arrow.From.Place != nil && arrow.To.Transition != nil && *arrow.To.Transition == transition {
			if state[*arrow.From.Place] == 0 {
				return false, placesToRemove, placesToAdd
			}
			placesToRemove = append(placesToRemove, *arrow.From.Place)
		}
		if arrow.From.Transition != nil && arrow.To.Place != nil && *arrow.From.Transition == transition {
			if state[*arrow.To.Place] > 0 {
				return false, placesToRemove, placesToAdd
			}
			placesToAdd = append(placesToAdd, *arrow.To.Place)
		}
	}

	return true, placesToRemove, placesToAdd
}

func (cm *CoffeeMachine) ExecuteTransition(transition Action) bool {
	canExecute, placesToRemove, placesToAdd := cm.PrepareTransition(cm.State, transition)

	if !canExecute {
		return false
	}

	for _, place := range placesToRemove {
		cm.State[place]--
	}
	for _, place := range placesToAdd {
		cm.State[place]++
	}
	return true
}

func (cm *CoffeeMachine) ExecuteProcess() {
	step := 0
	for {
		anyExecuted := false
		for _, transition := range []Action{BoilWater, GrindBeans, BrewCoffee, PourCoffee, Send, Credit} {
			if cm.ExecuteTransition(transition) {
				anyExecuted = true
				step++
				fmt.Printf("Step #%d: %v => %v\n", step, transition, cm.FilteredState())
				break
			}
		}
		if !anyExecuted {
			break
		}
	}
}

func (cm *CoffeeMachine) FilteredState() []string {
	filteredState := []string{}
	for state, count := range cm.State {
		if count > 0 {
			filteredState = append(filteredState, fmt.Sprintf("%v", state))
		}
	}
	return filteredState
}

func main() {
	cm := NewCoffeeMachine()
	cm.ExecuteProcess()
}
