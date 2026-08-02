# Coffee Machine State Machine

One Petri net, implemented thirty times: four *forms* across nine languages,
every one of them emitting the byte-identical canonical trace.

[![pflow](https://pflow.dev/img/zb2rhjeJ8bKSGRDHYv1e4Ap6wZrXvF6hqQkGYW7B1hk1KBsWa.svg)](https://pflow.dev/p/zb2rhjeJ8bKSGRDHYv1e4Ap6wZrXvF6hqQkGYW7B1hk1KBsWa/)

Click the image to open the model in the [PFlow](https://pflow.dev) editor. The
same model is checked in as [`model.json`](model.json), which is what
`tools/codegen` reads.

## The model

- **Places** hold tokens: `Water`, `BoiledWater`, `GroundCoffee`, `CoffeeInPot`, …
- **Transitions** move them: `BoilWater`, `GrindBeans`, `BrewCoffee`, `PourCoffee`, `Send`, `Credit`
- **Arcs** wire places to transitions and back
- **One guard**: `PourCoffee` requires `Payment` to be present, and does not
  consume it — you cannot pour before paying

The net is 1-safe: a place holds zero or one token, and a transition that would
produce into an already-marked place is not enabled.

## The canonical trace

Every implementation prints exactly this, and nothing else:

```
Step #1: BoilWater => BoiledWater,CoffeeBeans,Cup,Filter,Pending
Step #2: GrindBeans => BoiledWater,Cup,Filter,GroundCoffee,Pending
Step #3: BrewCoffee => CoffeeInPot,Cup,Pending
Step #4: Send => CoffeeInPot,Cup,Sent
Step #5: Credit => CoffeeInPot,Cup,Payment
Step #6: PourCoffee => Payment
```

That text is [`parity/trace.golden`](parity/trace.golden) — the contract every
implementation is held to. The transition name, then the marking as place names
sorted lexicographically. Sorting is not cosmetic: it is the only reason a Go
`map`, a Rust `HashSet`, a Python `set` and a JS `Set` can be compared at all.

The implementations are independent rewrites, so an identical trace is a real
claim about the model rather than a shared-code tautology.

## The four forms

The interesting variation is not "the same program in nine syntaxes" — it is
*how the model is encoded*. Four strategies recur:

| Form | The net is… | Firing order comes from… |
|------|-------------|--------------------------|
| **interpreter** | runtime data (`arrows`, `guards`) | a scheduler searching for an enabled transition |
| **lambda** | pure `State → State` functions | a fixed composition order chosen by the author |
| **generated** | a build-time input (`model.json`) | a generated scheduler |
| **contract** | a public API surface | the *caller* |

[FORMS.md](FORMS.md) specifies each one precisely, including why all four are
held to a single golden trace rather than one golden per form.

## The form × language matrix

| | interpreter | lambda | generated | contract |
|---|---|---|---|---|
| **Go** | ✅ | ✅ | ✅ | ✅ |
| **Rust** | ✅ | ✅ | ✅ | ✅ |
| **Python** | ✅ | ✅ | ✅ | ✅ |
| **JavaScript** | ✅ | ✅ | ✅ | ✅ |
| **Ruby** | ✅ | ✅ | — | ✅ |
| **Julia** | ✅ | ✅ | — | ✅ |
| **Haskell** | ✅ | ✅ | — | ✅ |
| **Bash** | ✅ | ✅ | — | ✅ |
| **Solidity** | — | — | ✅ | ✅ |

Thirty programs. The gaps are deliberate:

- **generated** exists for the four languages `tools/codegen` targets, plus
  Solidity. Adding a language means adding one template — see below.
- **Solidity** has no scheduler and no stdout, so interpreter and lambda have
  nowhere to land. Contract is the form the language forces on you, which is
  exactly why it is worth showing.

Layout is uniform: `<lang>/<form>` where the language needs directories (Go,
Rust) and `<lang>/<form>.<ext>` where it does not.

## Running them

```
make all            # every form in every locally available language
make run-go         # all four Go forms      (also run-rust, run-python, run-js)
make run-bash       # all three Bash forms   (also run-ruby, run-julia, run-haskell)
make help
```

## Parity gates

Two gates, because two kinds of toolchain:

```
make parity         # bazel test //... — the 16 in-graph programs, hermetically
make parity-native  # ruby, julia, haskell, bash against the same golden
```

**`make parity`** builds Go, Rust, Python and JavaScript under hermetic
toolchains (Go SDK 1.26.0, Rust 1.86.0, Node 22.14.0, CPython 3.12), runs all
sixteen programs, and diffs each one's stdout against the golden. If any drifts,
the build fails and the diff names it. It also runs
`//tools/codegen:codegen_up_to_date_test`, which regenerates every generated
file and fails if the checked-in output has gone stale.

Pins match the ecosystem-wide line (rules_go 0.61.1 / gazelle 0.51.3 / Go SDK
1.26.0) so compiled actions share cache keys with the other Bazel repos in the
Workspace. The shared remote cache is opt-in and read-only by default:

```
bazel test --config=remote //...     # needs ~/.netrc for bazel.stackdump.com
```

**`make parity-native`** covers what Bazel does not. It runs whichever of
ruby/julia/haskell/bash are installed and **skips** the rest — loudly. A run
where everything skipped exits 0 but says `NOTHING CHECKED`, so a missing
toolchain can never masquerade as a pass.

**Solidity is in neither gate.** There is no hermetic solc here and a contract
has no stdout; the event log is the trace, which would need an EVM to observe.
Both `.sol` files compile clean under solc 0.8.24, and the generated one is
still covered by the codegen drift test — but nothing asserts their behaviour.
That is the one honest gap in the matrix.

## Code generation

[`model.json`](model.json) is the source of truth for the generated form.

```
make generate         # regenerate every <lang>/generated from model.json
make check-generated  # fail if any of them is stale
```

Generated files carry a `DO NOT EDIT` header and are checked in, so the repo
stays readable without running the generator. `tools/codegen` is a single Go
program with one `text/template` per target language
([`tools/codegen/templates/`](tools/codegen/templates/)); adding a language is
one template plus one line in the `langs` map.

Output is deterministic — places, transitions and arc lists are all sorted by
name — which is what makes the drift test possible.

One consequence worth knowing: generated code schedules transitions in **sorted**
order (`BoilWater, BrewCoffee, Credit, GrindBeans, PourCoffee, Send`), while the
interpreter form schedules in **declaration** order. Both produce the golden
trace, because at every step of this net exactly one transition is enabled. That
is a property of this model, not a guarantee — the golden is what protects you.

## Per-language notes

Native test suites, where they exist:

```
cd golang && go test ./...
cargo test --manifest-path rust/Cargo.toml
cd python && PYTHONPATH=. python3 test/main_test.py
cd javascript && npm install && npm test        # mocha; not in the Bazel graph
```

- **Python**'s lambda form is `lambda_form.py` because `lambda` is a keyword.
- **Ruby**'s contract form spells `Send` as `send_order`, because `Object#send`
  is Ruby's reflection entry point and overriding it on a public API object is a
  trap.
- **Haskell**'s lambda form is the one that needs no scaffolding: `Maybe
  Marking` *is* "(marking, fired)", and the purity the other languages arrange
  by copying is free.
- **Julia**'s enum members carry the canonical CamelCase names directly, so
  `string(t)` gives the trace spelling with no name table.
- **JavaScript**'s mocha suite needs npm, which does not fit the dependency-free
  hermetic Node setup, so it stays outside `bazel test`.

## Contributing

New languages and new forms are both welcome. The bar is the same either way:
it must emit the canonical trace, and it must be wired into one of the two
parity gates. Start from [FORMS.md](FORMS.md) — it is the spec, not a
description.
