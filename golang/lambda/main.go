// Lambda form: the net is a set of pure Marking -> (Marking, bool) functions
// composed in a fixed schedule. No arrows, no guards list, no enablement
// search — the arcs survive only as control flow inside each transition.
//
// The fixed schedule is not an independent authorial choice: it is the firing
// sequence the canonical scheduling policy yields, precomputed with the search
// removed.
//
// See FORMS.md; output must match parity/trace.golden.
package main

import (
	"fmt"
	"sort"
	"strings"
)

// Marking is the set of currently-marked places. The net is 1-safe, so
// membership is all that matters.
type Marking map[string]bool

func (m Marking) has(places ...string) bool {
	for _, p := range places {
		if !m[p] {
			return false
		}
	}
	return true
}

func (m Marking) empty(places ...string) bool {
	for _, p := range places {
		if m[p] {
			return false
		}
	}
	return true
}

// fire returns a copy of m with the input places cleared and the output places
// set. It does not check enablement; each transition does that itself.
func (m Marking) fire(remove, add []string) Marking {
	next := make(Marking, len(m))
	for p, marked := range m {
		next[p] = marked
	}
	for _, p := range remove {
		delete(next, p)
	}
	for _, p := range add {
		next[p] = true
	}
	return next
}

func (m Marking) String() string {
	places := make([]string, 0, len(m))
	for p, marked := range m {
		if marked {
			places = append(places, p)
		}
	}
	sort.Strings(places)
	return strings.Join(places, ",")
}

type transition struct {
	name string
	fn   func(Marking) (Marking, bool)
}

func boilWater(m Marking) (Marking, bool) {
	if !m.has("Water") || !m.empty("BoiledWater") {
		return m, false
	}
	return m.fire([]string{"Water"}, []string{"BoiledWater"}), true
}

func grindBeans(m Marking) (Marking, bool) {
	if !m.has("CoffeeBeans") || !m.empty("GroundCoffee") {
		return m, false
	}
	return m.fire([]string{"CoffeeBeans"}, []string{"GroundCoffee"}), true
}

func brewCoffee(m Marking) (Marking, bool) {
	if !m.has("BoiledWater", "GroundCoffee", "Filter") || !m.empty("CoffeeInPot") {
		return m, false
	}
	return m.fire([]string{"BoiledWater", "GroundCoffee", "Filter"}, []string{"CoffeeInPot"}), true
}

func send(m Marking) (Marking, bool) {
	if !m.has("Pending") || !m.empty("Sent") {
		return m, false
	}
	return m.fire([]string{"Pending"}, []string{"Sent"}), true
}

func credit(m Marking) (Marking, bool) {
	if !m.has("Sent") || !m.empty("Payment") {
		return m, false
	}
	return m.fire([]string{"Sent"}, []string{"Payment"}), true
}

// pourCoffee carries the model's one guard: Payment must be present, and is
// not consumed.
func pourCoffee(m Marking) (Marking, bool) {
	if !m.has("Payment") {
		return m, false
	}
	if !m.has("CoffeeInPot", "Cup") {
		return m, false
	}
	return m.fire([]string{"CoffeeInPot", "Cup"}, nil), true
}

func initialMarking() Marking {
	return Marking{"Water": true, "CoffeeBeans": true, "Filter": true, "Cup": true, "Pending": true}
}

// schedule is the canonical firing order. Unlike the interpreter form, nothing
// here searches for it — it is the author's claim about the model.
var schedule = []transition{
	{"BoilWater", boilWater},
	{"GrindBeans", grindBeans},
	{"BrewCoffee", brewCoffee},
	{"Send", send},
	{"Credit", credit},
	{"PourCoffee", pourCoffee},
}

func main() {
	marking := initialMarking()
	step := 0
	for _, t := range schedule {
		next, fired := t.fn(marking)
		if !fired {
			continue
		}
		marking = next
		step++
		fmt.Printf("Step #%d: %s => %s\n", step, t.name, marking)
	}
}
