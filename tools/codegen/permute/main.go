// Command permute rewrites model.json with its places, transitions and arcs in
// a different order, preserving the net exactly.
//
//	permute -order reverse model.json > permuted.json
//	permute -order seed:7  model.json > permuted.json
//
// This exists to make a specific claim testable: the generated form must be a
// function of the *net*, not of how model.json happens to be typed. JSON objects
// are unordered by spec but ordered on disk, and it would be easy to write a
// generator whose output silently depended on that order — Go's map iteration is
// randomized, so such a bug would surface as flaky regeneration rather than as a
// clean failure.
//
// tools/codegen defends against this by sorting every list it emits;
// //tools/codegen:codegen_permutation_test is what proves the defence works, by
// regenerating from permuted models and requiring byte-identical output.
//
// See FORMS.md § generated.
package main

import (
	"bytes"
	"encoding/json"
	"flag"
	"fmt"
	"math/rand"
	"os"
	"strconv"
	"strings"
)

// object is a JSON object with its on-disk key order preserved. encoding/json
// unmarshals objects into maps, which loses exactly the thing this tool needs
// to manipulate, so keys are captured from the token stream instead.
type object struct {
	keys []string
	vals map[string]json.RawMessage
}

func parseObject(raw []byte) (*object, error) {
	dec := json.NewDecoder(bytes.NewReader(raw))
	tok, err := dec.Token()
	if err != nil {
		return nil, err
	}
	if delim, ok := tok.(json.Delim); !ok || delim != '{' {
		return nil, fmt.Errorf("expected object, got %v", tok)
	}

	obj := &object{vals: map[string]json.RawMessage{}}
	for dec.More() {
		keyTok, err := dec.Token()
		if err != nil {
			return nil, err
		}
		key, ok := keyTok.(string)
		if !ok {
			return nil, fmt.Errorf("expected object key, got %v", keyTok)
		}
		var val json.RawMessage
		if err := dec.Decode(&val); err != nil {
			return nil, err
		}
		obj.keys = append(obj.keys, key)
		obj.vals[key] = val
	}
	return obj, nil
}

func (o *object) render(order []string, indent string) string {
	var b strings.Builder
	b.WriteString("{\n")
	for i, k := range order {
		b.WriteString(indent + "  " + strconv.Quote(k) + ": ")
		b.Write(o.vals[k])
		if i < len(order)-1 {
			b.WriteString(",")
		}
		b.WriteString("\n")
	}
	b.WriteString(indent + "}")
	return b.String()
}

// reversed returns keys in reverse-lexicographic order — the permutation most
// likely to catch an accidental dependence on alphabetical input, since
// model.json is alphabetically ordered today.
func reversed(keys []string) []string {
	out := append([]string(nil), keys...)
	sorted := append([]string(nil), keys...)
	// sort descending without importing sort for one call
	for i := range sorted {
		for j := i + 1; j < len(sorted); j++ {
			if sorted[j] > sorted[i] {
				sorted[i], sorted[j] = sorted[j], sorted[i]
			}
		}
	}
	copy(out, sorted)
	return out
}

func shuffled(keys []string, rng *rand.Rand) []string {
	out := append([]string(nil), keys...)
	rng.Shuffle(len(out), func(i, j int) { out[i], out[j] = out[j], out[i] })
	return out
}

func main() {
	order := flag.String("order", "reverse", `permutation: "reverse" or "seed:<n>"`)
	flag.Parse()

	if flag.NArg() != 1 {
		fmt.Fprintln(os.Stderr, "usage: permute [-order reverse|seed:<n>] <model.json>")
		os.Exit(2)
	}

	raw, err := os.ReadFile(flag.Arg(0))
	if err != nil {
		fmt.Fprintln(os.Stderr, "permute:", err)
		os.Exit(1)
	}

	top, err := parseObject(raw)
	if err != nil {
		fmt.Fprintln(os.Stderr, "permute: parsing model:", err)
		os.Exit(1)
	}

	var permute func([]string) []string
	switch {
	case *order == "reverse":
		permute = reversed
	case strings.HasPrefix(*order, "seed:"):
		n, err := strconv.ParseInt(strings.TrimPrefix(*order, "seed:"), 10, 64)
		if err != nil {
			fmt.Fprintf(os.Stderr, "permute: bad seed %q: %v\n", *order, err)
			os.Exit(2)
		}
		// Fixed seed: the same -order flag always yields the same file, so a
		// failure is reproducible rather than a one-off.
		rng := rand.New(rand.NewSource(n))
		permute = func(keys []string) []string { return shuffled(keys, rng) }
	default:
		fmt.Fprintf(os.Stderr, "permute: unknown -order %q\n", *order)
		os.Exit(2)
	}

	var b strings.Builder
	b.WriteString("{\n")
	for i, key := range top.keys {
		b.WriteString("  " + strconv.Quote(key) + ": ")
		switch key {
		case "places", "transitions":
			obj, err := parseObject(top.vals[key])
			if err != nil {
				fmt.Fprintf(os.Stderr, "permute: parsing %s: %v\n", key, err)
				os.Exit(1)
			}
			b.WriteString(obj.render(permute(obj.keys), "  "))
		case "arcs":
			var arcs []json.RawMessage
			if err := json.Unmarshal(top.vals[key], &arcs); err != nil {
				fmt.Fprintln(os.Stderr, "permute: parsing arcs:", err)
				os.Exit(1)
			}
			idx := make([]string, len(arcs))
			for j := range arcs {
				idx[j] = fmt.Sprintf("%03d", j)
			}
			b.WriteString("[\n")
			for n, k := range permute(idx) {
				j, _ := strconv.Atoi(k)
				b.WriteString("    ")
				b.Write(arcs[j])
				if n < len(arcs)-1 {
					b.WriteString(",")
				}
				b.WriteString("\n")
			}
			b.WriteString("  ]")
		default:
			b.Write(top.vals[key])
		}
		if i < len(top.keys)-1 {
			b.WriteString(",")
		}
		b.WriteString("\n")
	}
	b.WriteString("}\n")

	fmt.Print(b.String())
}
