# The four forms

Every implementation in this repo models the same coffee-machine Petri net
([`model.json`](model.json)), and every one emits the byte-identical canonical
trace in [`parity/trace.golden`](parity/trace.golden).

What differs is *how the model is encoded in the host language*. Four forms
recur across languages, and each says something different about the model:

| Form | The net is… | Firing order comes from… | Guards live in… |
|------|-------------|--------------------------|-----------------|
| **interpreter** | runtime data (`arrows`, `guards`) | a scheduler searching for an enabled transition | the `guards` list, checked generically |
| **lambda** | a set of pure `State → State` functions | a fixed composition order chosen by the author | each transition's own precondition |
| **generated** | a build-time input (`model.json`) | a generated scheduler, transitions in sorted order | unrolled into the generated preconditions |
| **contract** | a public API surface | the *caller* | the entry point, which refuses to fire |

The forms are a matrix against languages; see the coverage table in
[README.md](README.md#the-form--language-matrix).

## Why one golden trace for all four

A form is an implementation strategy, not a different machine. If the lambda
form in Ruby and the generated form in Rust both print

```
Step #1: BoilWater => BoiledWater,CoffeeBeans,Cup,Filter,Pending
```

then the model is specified unambiguously enough that neither the language nor
the encoding strategy can change the answer. That is the whole claim the repo
makes, and `bazel test //...` is what keeps it true.

Holding all four forms to one golden costs something, and it is worth naming:
the lambda form previously composed `[boilWater, grindBeans, brewCoffee,
pourCoffee, send, credit]` and had no payment guard, so it poured before paying
and reached a different final marking. Its schedule is now the canonical firing
order and `pourCoffee` carries the guard. The form is still "fixed schedule, no
search" — it is just a *correct* fixed schedule.

## Canonical semantics

Every form, in every language, must implement exactly this. Where a language's
natural idiom disagrees, the spec wins.

**Marking.** A set of place names. The net is 1-safe: every place holds zero or
one token. A transition that would produce a token into an already-marked place
is *not* enabled (this is what `capacity: 1` in `model.json` means).

**Enablement.** Transition `t` is enabled in marking `M` iff:
1. every place with an arc *into* `t` is in `M`, and
2. no place with an arc *out of* `t` is in `M`, and
3. every guard on `t` is satisfied.

**Firing.** Remove all input places from `M`, then add all output places.
Enablement is computed against the pre-marking; a transition never observes its
own partial effect.

**Guards.** One guard: `PourCoffee` requires `Payment` to be present, and does
not consume it. In `model.json` this is the arc
`{"source": "PourCoffee", "target": "Payment", "inhibit": true}`.

**Trace line.** Exactly one line per firing, no trailing whitespace:

```
Step #<n>: <TransitionName> => <place>,<place>,...
```

`<n>` is 1-based. Places are the marking *after* firing, sorted
lexicographically by ASCII, comma-separated with no spaces. Nothing else goes
to stdout — no banner, no initial marking, no final summary.

Sorting is not cosmetic. It is the only reason a Go `map`, a Rust `HashSet`, a
Python `set` and a JS `Set` can be compared at all; all four have unspecified
or insertion-dependent iteration order.

**Names.** Places and transitions use the CamelCase names from `model.json`
(`BoiledWater`, `PourCoffee`) in output, regardless of the identifier
convention the language uses internally. Python's enum members stay
`UPPER_SNAKE` and carry the canonical name as their value; Rust derives it from
`Debug`; Julia and Bash map their `UPPER_SNAKE` enums through a name table.

## Form details

### interpreter

The reference form, and the only one where "same model, different language" is
literally true — the net is data, so the eight implementations differ only in
how they spell a list of pairs.

```
arrows  : [(from: Node, to: Node)]     Node = Place(p) | Transition(t)
guards  : [(from: Node, to: Node)]
```

`prepare_transition(M, t) -> (enabled, toRemove, toAdd)` is pure and does the
whole enablement check; `execute_transition` applies it; `execute_process`
loops, firing the **first enabled transition in declaration order** until none
is enabled.

Declaration order is load-bearing and easy to break by accident — reordering an
enum silently changes the trace. It is also, for this model, not actually
load-bearing: the generated form schedules in sorted order
(`BoilWater, BrewCoffee, Credit, GrindBeans, PourCoffee, Send`) and produces the
same trace anyway, because at every step exactly one transition is enabled.
That is a property of this net, not a guarantee. The golden is what protects
you.

### lambda

No net data at all. Each transition is a pure function from marking to marking
paired with a "did it fire" flag:

```
boilWater : Marking -> (Marking, Bool)
```

The preconditions are inlined into each function, so the arcs exist only as
control flow. A fixed schedule composes them:

```
BoilWater, GrindBeans, BrewCoffee, Send, Credit, PourCoffee
```

This form cannot answer "what is enabled now?" — it can only be run. That is
the point of contrasting it with the interpreter.

### generated

`model.json` → [`tools/codegen`](tools/codegen/) → source, checked in under
`<lang>/generated/`. The generated program is interpreter-shaped (a scheduler
loop) but with every arc unrolled into straight-line conditionals, so it has no
`arrows` list to walk at runtime.

Generated files carry a `Code generated by tools/codegen; DO NOT EDIT.` header.
`//tools/codegen:codegen_up_to_date_test` re-runs the generator and fails if the
checked-in output has drifted, so the model and the code cannot disagree.

Transitions are emitted in sorted name order because Go's `text/template`
iterates maps in sorted key order — deterministic, but not the same as the
interpreter's declaration order. See the note above about why both work here.

### contract

Inverted control: there is no scheduler and no schedule. Each transition is a
public method that either fires and records an event, or refuses:

```
pourCoffee() -> error   // "PourCoffee not enabled"
```

The caller sequences them. The driver in each language calls the six
transitions in canonical order and prints the trace as they succeed; the
methods themselves would equally accept any other order and reject what is not
enabled.

This is the form Solidity forces on you — [`solidity/contract.sol`](solidity/contract.sol)
enforces enablement with `require` in modifiers and emits one event per firing,
so the event log *is* the trace. The other languages implement the same shape
so the comparison is visible.
