// Proof form: the net is a claim about every reachable marking, checked by an
// exhaustive model-check before a single trace line is printed. See FORMS.md;
// output must match parity/trace.golden.
//
// The marking is a multiset — a count per place, not a set — and enablement is
// plain P/T semantics with no `capacity: 1` clause. Startup verifies:
//
//  1. 1-safety is structural: no reachable marking holds two tokens anywhere,
//     even without the capacity clause. This licenses the set representation
//     every other form uses.
//  2. The outcome is confluent: every reachable deadlock is exactly {Payment}.
//
// A violation aborts with the offending marking on stderr — which fails the
// parity gate, since a program that dies cannot print six lines.
package main

import (
	"fmt"
	"os"
	"sort"
	"strings"
)

// Places in a fixed order, so a marking is a plain []int and a map key is a
// deterministic join of counts.
var places = []string{
	"Water", "BoiledWater", "CoffeeBeans", "GroundCoffee", "Filter",
	"CoffeeInPot", "Pending", "Sent", "Payment", "Cup",
}

var placeIndex = func() map[string]int {
	idx := make(map[string]int, len(places))
	for i, p := range places {
		idx[p] = i
	}
	return idx
}()

// Marking is a token count per place, indexed like places.
type Marking []int

func (m Marking) clone() Marking {
	next := make(Marking, len(m))
	copy(next, m)
	return next
}

// key is the map identity of a marking. Counts joined in place order — no
// hashing subtleties, no sorting.
func (m Marking) key() string {
	parts := make([]string, len(m))
	for i, c := range m {
		parts[i] = fmt.Sprint(c)
	}
	return strings.Join(parts, ",")
}

// render is the canonical trace form: marked places, sorted, comma-joined.
func (m Marking) render() string {
	marked := []string{}
	for i, c := range m {
		if c > 0 {
			marked = append(marked, places[i])
		}
	}
	sort.Strings(marked)
	return strings.Join(marked, ",")
}

// Transition inputs are consumed, outputs produced, guards read but not
// consumed.
type Transition struct {
	Name    string
	Inputs  []string
	Outputs []string
	Guards  []string
}

// The net. Sorted by name in init below, which is what makes the trace loop
// implement the canonical scheduling policy (FORMS.md): fire the enabled
// transition whose name is lexicographically least. The order written here is
// therefore not load-bearing — but do not assume that and drop the sort, since
// only 90 of the 720 possible orders produce parity/trace.golden.
var transitions = []Transition{
	{"BoilWater", []string{"Water"}, []string{"BoiledWater"}, nil},
	{"GrindBeans", []string{"CoffeeBeans"}, []string{"GroundCoffee"}, nil},
	{"BrewCoffee", []string{"BoiledWater", "GroundCoffee", "Filter"}, []string{"CoffeeInPot"}, nil},
	{"PourCoffee", []string{"CoffeeInPot", "Cup"}, nil, []string{"Payment"}},
	{"Send", []string{"Pending"}, []string{"Sent"}, nil},
	{"Credit", []string{"Sent"}, []string{"Payment"}, nil},
}

func init() {
	sort.Slice(transitions, func(i, j int) bool { return transitions[i].Name < transitions[j].Name })
}

func initialMarking() Marking {
	m := make(Marking, len(places))
	for _, p := range []string{"Water", "CoffeeBeans", "Filter", "Cup", "Pending"} {
		m[placeIndex[p]] = 1
	}
	return m
}

// enabled is plain P/T enablement: inputs and guards marked. Deliberately no
// "outputs clear" clause — that the clause is never needed is check 1.
func enabled(m Marking, t Transition) bool {
	for _, p := range t.Inputs {
		if m[placeIndex[p]] < 1 {
			return false
		}
	}
	for _, p := range t.Guards {
		if m[placeIndex[p]] < 1 {
			return false
		}
	}
	return true
}

func fire(m Marking, t Transition) Marking {
	next := m.clone()
	for _, p := range t.Inputs {
		next[placeIndex[p]]--
	}
	for _, p := range t.Outputs {
		next[placeIndex[p]]++
	}
	return next
}

func oneSafe(m Marking) bool {
	for _, c := range m {
		if c > 1 {
			return false
		}
	}
	return true
}

func isDeadlock(m Marking) bool {
	for _, t := range transitions {
		if enabled(m, t) {
			return false
		}
	}
	return true
}

// verify explores the full reachable state space by breadth-first search and
// checks both claims. An unsafe marking fails immediately, so the explored
// space is a subset of {0,1}^10 and the search needs no bound to terminate.
func verify() error {
	initial := initialMarking()
	seen := map[string]bool{initial.key(): true}
	frontier := []Marking{initial}
	deadlocks := []Marking{}

	for len(frontier) > 0 {
		m := frontier[0]
		frontier = frontier[1:]

		if !oneSafe(m) {
			return fmt.Errorf("1-safety violated: reachable marking %s", m.key())
		}

		fired := false
		for _, t := range transitions {
			if !enabled(m, t) {
				continue
			}
			fired = true
			next := fire(m, t)
			if !seen[next.key()] {
				seen[next.key()] = true
				frontier = append(frontier, next)
			}
		}
		if !fired {
			deadlocks = append(deadlocks, m)
		}
	}

	if len(deadlocks) != 1 || deadlocks[0].render() != "Payment" {
		got := make([]string, len(deadlocks))
		for i, d := range deadlocks {
			got[i] = "{" + d.render() + "}"
		}
		return fmt.Errorf("deadlock not unique {Payment}: got %s", strings.Join(got, " "))
	}
	return nil
}

// executeProcess is the interpreter form's scheduler, running on a net the
// model-check has already verified.
func executeProcess() {
	m := initialMarking()
	step := 0
	for {
		fired := false
		for _, t := range transitions {
			if enabled(m, t) {
				m = fire(m, t)
				step++
				fmt.Printf("Step #%d: %s => %s\n", step, t.Name, m.render())
				fired = true
				break
			}
		}
		if !fired {
			return
		}
	}
}

func main() {
	if err := verify(); err != nil {
		fmt.Fprintln(os.Stderr, "proof failed:", err)
		os.Exit(1)
	}
	executeProcess()
}
