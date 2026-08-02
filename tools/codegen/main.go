// Command codegen turns model.json into a working implementation of the
// generated form (see FORMS.md) in one of several target languages.
//
//	go run ./tools/codegen -lang go model.json
//
// The emitted program is interpreter-shaped — a scheduler loop that fires the
// first enabled transition — but with every arc unrolled into straight-line
// conditionals, so nothing walks an arrow list at runtime.
//
// Output is deterministic: places, transitions and arc lists are all sorted by
// name, so regenerating an unchanged model produces byte-identical source.
// //tools/codegen:codegen_up_to_date_test depends on that.
package main

import (
	"bytes"
	"embed"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"sort"
	"strings"
	"text/template"
)

//go:embed templates/*.tmpl
var templates embed.FS

// --- model.json ------------------------------------------------------------

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

type petriNet struct {
	Places      map[string]place           `json:"places"`
	Transitions map[string]json.RawMessage `json:"transitions"`
	Arcs        []arc                      `json:"arcs"`
}

// --- normalized form handed to the templates -------------------------------

// Transition is one transition with its arcs resolved and classified. The four
// lists are exactly the four clauses of the enablement rule in FORMS.md.
type Transition struct {
	Name     string
	Inputs   []string // places consumed; must be marked
	Outputs  []string // places produced; must be clear (the net is 1-safe)
	Guards   []string // must be marked, not consumed
	Blockers []string // must be clear, not produced
}

type Model struct {
	Places      []string // every place, sorted
	Initial     []string // initially marked places, sorted
	Transitions []Transition
}

func normalize(net petriNet) (Model, error) {
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

// --- template helpers ------------------------------------------------------

// lowerFirst turns BoilWater into boilWater for languages that want unexported
// or camelCase function names.
func lowerFirst(s string) string {
	if s == "" {
		return s
	}
	return strings.ToLower(s[:1]) + s[1:]
}

// snake turns BoilWater into boil_water for Python and Rust.
func snake(s string) string {
	var b strings.Builder
	for i, r := range s {
		if r >= 'A' && r <= 'Z' {
			if i > 0 {
				b.WriteByte('_')
			}
			b.WriteRune(r + ('a' - 'A'))
			continue
		}
		b.WriteRune(r)
	}
	return b.String()
}

// quoteAll renders a list of names as a language-specific literal list body,
// e.g. `"Water", "Cup"`.
func quoteAll(names []string) string {
	quoted := make([]string, len(names))
	for i, n := range names {
		quoted[i] = `"` + n + `"`
	}
	return strings.Join(quoted, ", ")
}

var funcs = template.FuncMap{
	"lowerFirst": lowerFirst,
	"snake":      snake,
	"quoteAll":   quoteAll,
	"join":       strings.Join,
}

var langs = map[string]string{
	"go":       "templates/go.tmpl",
	"rust":     "templates/rust.tmpl",
	"python":   "templates/python.tmpl",
	"js":       "templates/js.tmpl",
	"solidity": "templates/solidity.tmpl",
}

func main() {
	lang := flag.String("lang", "", "target language: go, rust, python, js, solidity")
	out := flag.String("out", "", "output file (default: stdout)")
	flag.Parse()

	if flag.NArg() != 1 {
		fmt.Fprintln(os.Stderr, "usage: codegen -lang <lang> [-out <file>] <model.json>")
		os.Exit(2)
	}

	tmplPath, ok := langs[*lang]
	if !ok {
		names := make([]string, 0, len(langs))
		for n := range langs {
			names = append(names, n)
		}
		sort.Strings(names)
		fmt.Fprintf(os.Stderr, "unknown -lang %q (have: %s)\n", *lang, strings.Join(names, ", "))
		os.Exit(2)
	}

	raw, err := os.ReadFile(flag.Arg(0))
	if err != nil {
		fmt.Fprintln(os.Stderr, "codegen:", err)
		os.Exit(1)
	}

	var net petriNet
	if err := json.Unmarshal(raw, &net); err != nil {
		fmt.Fprintln(os.Stderr, "codegen: parsing model:", err)
		os.Exit(1)
	}

	model, err := normalize(net)
	if err != nil {
		fmt.Fprintln(os.Stderr, "codegen:", err)
		os.Exit(1)
	}

	tmpl, err := template.New(*lang).Funcs(funcs).ParseFS(templates, tmplPath)
	if err != nil {
		fmt.Fprintln(os.Stderr, "codegen: parsing template:", err)
		os.Exit(1)
	}

	var buf bytes.Buffer
	if err := tmpl.ExecuteTemplate(&buf, "main", model); err != nil {
		fmt.Fprintln(os.Stderr, "codegen: rendering:", err)
		os.Exit(1)
	}

	if *out == "" {
		os.Stdout.Write(buf.Bytes())
		return
	}
	if err := os.WriteFile(*out, buf.Bytes(), 0o644); err != nil {
		fmt.Fprintln(os.Stderr, "codegen:", err)
		os.Exit(1)
	}
}
