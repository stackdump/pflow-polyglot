// Package petri parses model.json and implements the canonical semantics from
// FORMS.md.
//
// It exists so that the two tools reading the model — the code generator and
// the reachability-space generator — cannot disagree about what the net is.
// Both the generated implementations and parity/reachability.golden are
// downstream of this one enablement rule; two copies of it would eventually
// describe two different machines, and the artifact whose job is to referee the
// six proof forms would be the thing that had drifted.
package petri

import (
	"encoding/json"
	"fmt"
	"os"
	"sort"
)

type place struct {
	Offset   int `json:"offset"`
	Initial  int `json:"initial"`
	Capacity int `json:"capacity"`
}

type arc struct {
	Source  string `json:"source"`
	Target  string `json:"target"`
	Inhibit bool   `json:"inhibit"`
}

type netJSON struct {
	Places      map[string]place           `json:"places"`
	Transitions map[string]json.RawMessage `json:"transitions"`
	Arcs        []arc                      `json:"arcs"`
}

// Transition is one transition with its arcs resolved and classified. The four
// lists are exactly the four clauses of the enablement rule in FORMS.md.
type Transition struct {
	Name     string
	Inputs   []string // places consumed; must be marked
	Outputs  []string // places produced; must be clear (the net is 1-safe)
	Guards   []string // must be marked, not consumed
	Blockers []string // must be clear, not produced
}

// Model is the normalized net. Every list is sorted by name, so a Model is a
// function of the net alone and not of model.json's key order —
// //tools/codegen:codegen_permutation_test is what holds that true.
type Model struct {
	Places      []string // every place, sorted
	Initial     []string // initially marked places, sorted
	Transitions []Transition
}

// Load reads and normalizes a model.json.
func Load(path string) (Model, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return Model{}, err
	}
	var net netJSON
	if err := json.Unmarshal(raw, &net); err != nil {
		return Model{}, fmt.Errorf("parsing model: %w", err)
	}
	return normalize(net)
}

func normalize(net netJSON) (Model, error) {
	m := Model{}

	isPlace := func(name string) bool {
		_, ok := net.Places[name]
		return ok
	}

	for name, p := range net.Places {
		m.Places = append(m.Places, name)
		if p.Initial > 0 {
			m.Initial = append(m.Initial, name)
		}
		if p.Capacity > 1 {
			return m, fmt.Errorf("place %s has capacity %d: the generated form is 1-safe only", name, p.Capacity)
		}
	}
	sort.Strings(m.Places)
	sort.Strings(m.Initial)

	byName := map[string]*Transition{}
	for name := range net.Transitions {
		byName[name] = &Transition{Name: name}
	}

	for _, a := range net.Arcs {
		switch {
		case isPlace(a.Source):
			t, ok := byName[a.Target]
			if !ok {
				return m, fmt.Errorf("arc %s -> %s: unknown transition", a.Source, a.Target)
			}
			// A place-to-transition inhibitor blocks rather than consumes.
			if a.Inhibit {
				t.Blockers = append(t.Blockers, a.Source)
			} else {
				t.Inputs = append(t.Inputs, a.Source)
			}
		case isPlace(a.Target):
			t, ok := byName[a.Source]
			if !ok {
				return m, fmt.Errorf("arc %s -> %s: unknown transition", a.Source, a.Target)
			}
			// A transition-to-place inhibitor is a read arc: the place must be
			// marked for the transition to fire, and is not consumed. This is
			// how model.json spells the PourCoffee/Payment guard.
			if a.Inhibit {
				t.Guards = append(t.Guards, a.Target)
			} else {
				t.Outputs = append(t.Outputs, a.Target)
			}
		default:
			return m, fmt.Errorf("arc %s -> %s: neither endpoint is a place", a.Source, a.Target)
		}
	}

	for _, t := range byName {
		sort.Strings(t.Inputs)
		sort.Strings(t.Outputs)
		sort.Strings(t.Guards)
		sort.Strings(t.Blockers)
		m.Transitions = append(m.Transitions, *t)
	}
	sort.Slice(m.Transitions, func(i, j int) bool { return m.Transitions[i].Name < m.Transitions[j].Name })

	return m, nil
}

// --- canonical semantics (FORMS.md) ----------------------------------------

// Marking is the set of marked places. The net is 1-safe, so a set — not a
// multiset — is a faithful representation. That this is faithful is not assumed
// here; it is what the proof form checks.
type Marking map[string]bool

// InitialMarking is the marking model.json declares.
func (m Model) InitialMarking() Marking {
	marking := Marking{}
	for _, p := range m.Initial {
		marking[p] = true
	}
	return marking
}

// Enabled reports whether t may fire in marking. All four clauses of the rule
// in FORMS.md: inputs marked, outputs clear, guards marked, blockers clear.
func Enabled(marking Marking, t Transition) bool {
	for _, p := range t.Inputs {
		if !marking[p] {
			return false
		}
	}
	for _, p := range t.Outputs {
		if marking[p] {
			return false
		}
	}
	for _, p := range t.Guards {
		if !marking[p] {
			return false
		}
	}
	for _, p := range t.Blockers {
		if marking[p] {
			return false
		}
	}
	return true
}

// EnabledIn returns the names of every transition enabled in marking, sorted —
// which makes the first element the one the canonical scheduling policy fires.
func (m Model) EnabledIn(marking Marking) []string {
	var names []string
	for _, t := range m.Transitions {
		if Enabled(marking, t) {
			names = append(names, t.Name)
		}
	}
	sort.Strings(names)
	return names
}

// Fire applies t to marking, returning a new marking. Enablement is computed
// against the pre-marking by the caller; a transition never observes its own
// partial effect.
func Fire(marking Marking, t Transition) Marking {
	next := Marking{}
	for p, v := range marking {
		if v {
			next[p] = true
		}
	}
	for _, p := range t.Inputs {
		delete(next, p)
	}
	for _, p := range t.Outputs {
		next[p] = true
	}
	return next
}

// Key renders a marking as its canonical sorted, comma-joined form — the same
// spelling the trace uses, so it doubles as a map key and as output.
func (marking Marking) Key() string {
	var marked []string
	for p, v := range marking {
		if v {
			marked = append(marked, p)
		}
	}
	sort.Strings(marked)
	out := ""
	for i, p := range marked {
		if i > 0 {
			out += ","
		}
		out += p
	}
	return out
}

// ByName returns the transition with the given name.
func (m Model) ByName(name string) (Transition, bool) {
	for _, t := range m.Transitions {
		if t.Name == name {
			return t, true
		}
	}
	return Transition{}, false
}
