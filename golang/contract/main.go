// Contract form: the net is a public API surface. There is no scheduler and no
// schedule — each transition is an entry point that either fires and records an
// event, or returns ErrNotEnabled. The caller decides the order.
//
// This mirrors solidity/contract.sol, where enablement is enforced by `require`
// in a modifier and the event log is the trace.
//
// See FORMS.md; output must match parity/trace.golden.
package main

import (
	"errors"
	"fmt"
	"sort"
	"strings"
)

// ErrNotEnabled is returned when a transition is called in a marking that does
// not enable it. The contract never panics and never partially applies.
var ErrNotEnabled = errors.New("transition not enabled")

// CoffeeMachine holds the marking and the log of fired transitions. Callers
// cannot reach the marking directly; the only way to change it is a transition.
type CoffeeMachine struct {
	marked map[string]bool
	events []string
}

func New() *CoffeeMachine {
	return &CoffeeMachine{
		marked: map[string]bool{
			"Water": true, "CoffeeBeans": true, "Filter": true, "Cup": true, "Pending": true,
		},
	}
}

// require is the enablement check every entry point runs first: all inputs
// marked, all outputs clear, all guards satisfied.
func (cm *CoffeeMachine) require(inputs, outputs, guards []string) error {
	for _, p := range inputs {
		if !cm.marked[p] {
			return fmt.Errorf("%w: missing input %s", ErrNotEnabled, p)
		}
	}
	for _, p := range outputs {
		if cm.marked[p] {
			return fmt.Errorf("%w: output %s already marked", ErrNotEnabled, p)
		}
	}
	for _, p := range guards {
		if !cm.marked[p] {
			return fmt.Errorf("%w: guard %s unsatisfied", ErrNotEnabled, p)
		}
	}
	return nil
}

func (cm *CoffeeMachine) fire(name string, inputs, outputs, guards []string) error {
	if err := cm.require(inputs, outputs, guards); err != nil {
		return err
	}
	for _, p := range inputs {
		delete(cm.marked, p)
	}
	for _, p := range outputs {
		cm.marked[p] = true
	}
	cm.events = append(cm.events, name)
	return nil
}

func (cm *CoffeeMachine) BoilWater() error {
	return cm.fire("BoilWater", []string{"Water"}, []string{"BoiledWater"}, nil)
}

func (cm *CoffeeMachine) GrindBeans() error {
	return cm.fire("GrindBeans", []string{"CoffeeBeans"}, []string{"GroundCoffee"}, nil)
}

func (cm *CoffeeMachine) BrewCoffee() error {
	return cm.fire("BrewCoffee", []string{"BoiledWater", "GroundCoffee", "Filter"}, []string{"CoffeeInPot"}, nil)
}

func (cm *CoffeeMachine) Send() error {
	return cm.fire("Send", []string{"Pending"}, []string{"Sent"}, nil)
}

func (cm *CoffeeMachine) Credit() error {
	return cm.fire("Credit", []string{"Sent"}, []string{"Payment"}, nil)
}

// PourCoffee is guarded on Payment, which it checks but does not consume.
func (cm *CoffeeMachine) PourCoffee() error {
	return cm.fire("PourCoffee", []string{"CoffeeInPot", "Cup"}, nil, []string{"Payment"})
}

// Marking is the contract's view function: the marked places, sorted.
func (cm *CoffeeMachine) Marking() string {
	places := make([]string, 0, len(cm.marked))
	for p, marked := range cm.marked {
		if marked {
			places = append(places, p)
		}
	}
	sort.Strings(places)
	return strings.Join(places, ",")
}

func main() {
	cm := New()

	// The driver is the caller, not the machine. Calling these in any other
	// order returns ErrNotEnabled rather than corrupting the marking.
	calls := []struct {
		name string
		call func() error
	}{
		{"BoilWater", cm.BoilWater},
		{"GrindBeans", cm.GrindBeans},
		{"BrewCoffee", cm.BrewCoffee},
		{"Send", cm.Send},
		{"Credit", cm.Credit},
		{"PourCoffee", cm.PourCoffee},
	}

	step := 0
	for _, c := range calls {
		if err := c.call(); err != nil {
			continue
		}
		step++
		fmt.Printf("Step #%d: %s => %s\n", step, c.name, cm.Marking())
	}
}
