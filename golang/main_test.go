package main

import (
	"testing"
)

func TestNewCoffeeMachine(t *testing.T) {
	cm := NewCoffeeMachine()
	expectedState := map[State]int{
		Water:       1,
		CoffeeBeans: 1,
		Filter:      1,
		Cup:         1,
		Pending:     1,
	}

	for state, count := range expectedState {
		if cm.State[state] != count {
			t.Errorf("Expected state %v to be %d, got %d", state, count, cm.State[state])
		}
	}
}

func TestCanExecute(t *testing.T) {
	cm := NewCoffeeMachine()

	if !cm.CanExecute(cm.State, BoilWater) {
		t.Errorf("Expected to be able to execute BoilWater")
	}

	if cm.CanExecute(cm.State, Credit) {
		t.Errorf("Expected not to be able to execute Credit")
	}
}

func TestExecuteTransition(t *testing.T) {
	cm := NewCoffeeMachine()

	if !cm.ExecuteTransition(BoilWater) {
		t.Errorf("Expected BoilWater transition to execute successfully")
	}

	if cm.State[Water] != 0 || cm.State[BoiledWater] != 1 {
		t.Errorf("Expected Water to be 0 and BoiledWater to be 1, got Water: %d, BoiledWater: %d", cm.State[Water], cm.State[BoiledWater])
	}
}

func TestExecuteProcess(t *testing.T) {
	cm := NewCoffeeMachine()
	cm.ExecuteProcess()

	expectedFinalState := map[State]int{
		Water:        0,
		BoiledWater:  0,
		CoffeeBeans:  0,
		GroundCoffee: 0,
		Filter:       0,
		CoffeeInPot:  0,
		Pending:      0,
		Sent:         0,
		Payment:      1,
		Cup:          0,
	}

	for state, count := range expectedFinalState {
		if cm.State[state] != count {
			t.Errorf("Expected state %v to be %d, got %d", state, count, cm.State[state])
		}
	}
}

func TestPourCoffeeNotEnabled(t *testing.T) {
	cm := NewCoffeeMachine()
	cm.State = make(map[State]int)
	cm.State[Cup] = 1
	cm.State[Pending] = 1
	cm.State[CoffeeInPot] = 1

	if cm.CanExecute(cm.State, PourCoffee) {
		t.Errorf("Expected PourCoffee not to be enabled in the state [Cup, Pending, CoffeeInPot]")
	}
}
