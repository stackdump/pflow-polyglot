// Command codegen turns model.json into a working implementation of the
// generated form (see FORMS.md) in one of several target languages.
//
//	go run ./tools/codegen -lang go model.json
//
// The emitted program is interpreter-shaped — a scheduler loop applying the
// canonical scheduling policy (FORMS.md): fire the enabled transition whose
// name is lexicographically least. Every arc is unrolled into straight-line
// conditionals, so nothing walks an arrow list at runtime.
//
// -lang lean emits the *proof* form instead: lean/proof.lean, whose theorems
// (1-safety, one conservation law per P-invariant of C, the unique deadlock)
// are derived from the model and discharged by `decide`.
//
// Output is deterministic: places, transitions and arc lists are all sorted by
// name, so regenerating an unchanged model produces byte-identical source.
// //tools/codegen:codegen_up_to_date_test depends on that.
package main

import (
	"bytes"
	"embed"
	"flag"
	"fmt"
	"os"
	"sort"
	"strings"
	"text/template"

	"github.com/stackdump/pflow-polyglot/tools/codegen/internal/petri"
)

//go:embed templates/*.tmpl
var templates embed.FS

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
	"lean":     "templates/lean.tmpl",
}

func main() {
	lang := flag.String("lang", "", "target language: go, rust, python, js, solidity, lean")
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

	model, err := petri.Load(flag.Arg(0))
	if err != nil {
		fmt.Fprintln(os.Stderr, "codegen:", err)
		os.Exit(1)
	}

	tmpl, err := template.New(*lang).Funcs(funcs).ParseFS(templates, tmplPath)
	if err != nil {
		fmt.Fprintln(os.Stderr, "codegen: parsing template:", err)
		os.Exit(1)
	}

	// The proof form states theorems rather than a scheduler, so its template
	// sees the model plus the analysis those theorems are derived from.
	var data any = model
	if *lang == "lean" {
		data = model.ProofView()
	}

	var buf bytes.Buffer
	if err := tmpl.ExecuteTemplate(&buf, "main", data); err != nil {
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
