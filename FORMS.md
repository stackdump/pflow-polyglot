# The five forms

Every implementation in this repo models the same coffee-machine Petri net
([`model.json`](model.json)), and every one emits the byte-identical canonical
trace in [`parity/trace.golden`](parity/trace.golden).

What differs is *how the model is encoded in the host language*. Five forms
recur across languages, and each says something different about the model:

| Form | The net is… | Firing order comes from… | Guards live in… |
|------|-------------|--------------------------|-----------------|
| **interpreter** | runtime data (`arrows`, `guards`) | a scheduler applying the [canonical scheduling policy](#canonical-scheduling-policy) | the `guards` list, checked generically |
| **lambda** | a set of pure `State → State` functions | a fixed composition order: the sequence the policy yields, precomputed | each transition's own precondition |
| **generated** | a build-time input (`model.json`) | a generated scheduler applying the same policy | unrolled into the generated preconditions |
| **contract** | a public API surface | the *caller*, who must supply the policy's sequence to match the golden | the entry point, which refuses to fire |
| **proof** | a claim about *every* reachable marking | the same policy, run only after the claim is checked | the enablement relation the model-check explores |

Every row cites one rule. That is deliberate: the five forms differ in *where*
the firing order is decided, not in *what* it is.

The forms are a matrix against languages; see the coverage table in
[README.md](README.md#the-form--language-matrix).

## Why one golden trace for all five

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

## The two goldens

`parity/trace.golden` pins one path. `parity/reachability.golden` pins the
machine that path runs through: every reachable marking, the transitions enabled
in each with their successor markings, and the set of terminal markings — 16
markings, 26 edges, one terminal.

The second exists because the first cannot express concurrency. A single trace
is equally consistent with a net that never offers a choice, so on its own it
cannot distinguish *the implementations agree about this machine* from *the
implementations agree about one path through a machine none of them has
explored*.

It also gives the [proof](#proof) forms something to be checked against. Six
languages compute this state space at startup, assert 1-safety and the unique
`{Payment}` deadlock, and then discard it. Six model-checkers that never compare
notes are six programs trusted on their own say-so; emitting the space once, as
a shared artifact, is what makes them checkable against each other rather than
individually plausible.

Both are generated from `model.json` and gated together by
`//tools/codegen:reachability_test`, which checks three things: the space is not
stale, it does not change when `model.json`'s keys are reordered, and applying
the [canonical scheduling policy](#canonical-scheduling-policy) to it reproduces
`trace.golden` exactly. That last check is what makes them a pair — neither
golden can move without the other noticing.

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

### Canonical scheduling policy

> **At each step, fire the enabled transition whose name is lexicographically
> least by ASCII. Stop when no transition is enabled.**

This is normative, and it is the *only* reason the thirty-nine programs can
share one golden trace. It is not a description of what they happen to do.

The rule is needed because **this net has genuine concurrency**. It is not the
case that exactly one transition is enabled at each step. On the golden path the
enabled sets are:

| Step | Marking | Enabled |
|------|---------|---------|
| 1 | `Water, CoffeeBeans, Filter, Pending, Cup` | **BoilWater, GrindBeans, Send** |
| 2 | `BoiledWater, CoffeeBeans, Cup, Filter, Pending` | **GrindBeans, Send** |
| 3 | `BoiledWater, Cup, Filter, GroundCoffee, Pending` | **BrewCoffee, Send** |
| 4 | `CoffeeInPot, Cup, Pending` | Send |
| 5 | `CoffeeInPot, Cup, Sent` | Credit |
| 6 | `CoffeeInPot, Cup, Payment` | PourCoffee |

Three of the six steps are choices. Over the whole reachable space, 9 of the 16
markings enable more than one transition, and the net admits **20 distinct
maximal firing sequences**. `parity/trace.golden` is one of those twenty — the
one this policy selects — not the only trace the net can produce.

A scheduler that instead fires "the first enabled transition in declaration
order" is only correct by accident: of the 720 possible static priority orders,
**90 reproduce the golden and 630 do not**. Any implementation that walks a
transition list must therefore sort it by name explicitly, rather than lean on
enum order, map order, or the order arcs happen to appear in `model.json`.

What the policy does *not* decide is where the net ends up. Every one of the 20
sequences terminates in the same marking `{Payment}`, because the net has no
conflict — no two transitions ever compete for a token. The [proof](#proof) form
checks exactly that, which is what makes the choice of policy a matter of
presentation rather than of outcome.

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
`Debug`; Julia and Bash map their `UPPER_SNAKE` enums through a name table;
Lean writes the table out by hand rather than deriving it, because `Repr` output
is a rendering decision and the trace is a contract.

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
loops, applying the [canonical scheduling policy](#canonical-scheduling-policy)
until nothing is enabled.

The candidate list must be **sorted by transition name at the point of
scheduling** — `sort`, `sort_by_key`, `sortOn show`, `LC_ALL=C sort`, whatever
the language spells it. Sorting is not a tidiness preference here: enum
declaration order, hash-map order and `model.json`'s key order are all
different orders, and only one of them yields the golden. Sorting explicitly is
what makes the form's output a consequence of the policy rather than of how
someone happened to type the enum.

Every interpreter implementation in this repo previously walked its enum in
declaration order (`BoilWater, GrindBeans, BrewCoffee, PourCoffee, Send,
Credit`), which is one of the 90 lucky orders. The trace was right; the reason
was not.

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

That sequence is not an independent authorial choice, and it is not free. It is
the [canonical scheduling policy](#canonical-scheduling-policy) *evaluated ahead
of time*: it is precisely the firing sequence the policy selects, with the
search removed because the answer is already known. Written any other way the
form would still run — 20 sequences are legal — but it would no longer match the
golden. If the policy ever changes, this list is the first thing that has to
change with it.

Note that the composition order is **not** the sorted order the interpreter
searches in; sorting picks the *candidate to consider*, while this list records
the *transitions actually fired*. The two coincide only at steps where one
transition is enabled.

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

Transitions are emitted in sorted name order, which makes the generated
scheduler an implementation of the
[canonical scheduling policy](#canonical-scheduling-policy) by construction: the
straight-line conditionals are tested in the same order the policy would
consider them.

`tools/codegen` sorts every list it emits — places, initial marking, and each
transition's inputs, outputs, guards and blockers — so the generated sources are
invariant under permutation of `model.json`'s keys. That is not incidental
tidiness either; it is what
[`//tools/codegen:codegen_permutation_test`](tools/codegen/) asserts, by
regenerating from reordered copies of the model and requiring byte-identical
output.

### contract

Inverted control: there is no scheduler and no schedule. Each transition is a
public method that either fires and records an event, or refuses:

```
pourCoffee() -> error   // "PourCoffee not enabled"
```

The caller sequences them. The driver in each language calls the six
transitions in the order the
[canonical scheduling policy](#canonical-scheduling-policy) yields — the same
precomputed sequence the lambda form composes — and prints the trace as they
succeed. The methods themselves would equally accept any other order and reject
what is not enabled.

The policy is therefore a constraint on the *driver*, not on the API. That is
the honest reading of "firing order comes from the caller": the caller is free,
but a caller that wants the golden trace has exactly one sequence available to
it. A driver that called `send()` first would fire a legal sequence and print a
legal trace — just not this one.

This is the form Solidity forces on you — [`solidity/contract.sol`](solidity/contract.sol)
enforces enablement with `require` in modifiers and emits one event per firing,
so the event log *is* the trace. The other languages implement the same shape
so the comparison is visible.

### proof

The other four forms *assert* the net's properties; this one checks them
before printing a line. The marking is a multiset — a count per place, not a
set — and enablement is plain P/T semantics: every input and guard place holds
a token. Deliberately absent is the `capacity: 1` clause the other forms carry.
The form then explores the full reachable state space by breadth-first search
and verifies two claims:

1. **1-safety is structural.** No reachable marking holds two tokens in any
   place, *even without the capacity clause*. This is what licenses every other
   implementation's set representation: the clause they enforce is never
   load-bearing, and a `Set` loses nothing a multiset would keep.
2. **The outcome is confluent.** The net has no conflict — no two transitions
   compete for a token — so every maximal firing sequence ends in the same
   deadlock, and it is exactly `{Payment}`. The golden trace's final marking is
   not one schedule's artifact; it is the only place the net can stop.

Claim 2 is what makes the [canonical scheduling
policy](#canonical-scheduling-policy) a presentational choice rather than a
semantic one. The policy picks which of the 20 maximal sequences gets printed;
confluence guarantees that all 20 agree about where the net ends up. Without
claim 2, choosing a scheduling rule would be choosing an outcome.

Only after both checks pass does the form run the scheduler under the same
policy and print the canonical trace. A violation aborts with a nonzero exit and the
offending marking on stderr — which fails the parity gate, since a program that
dies before printing six lines cannot match the golden.

The search needs no bound to terminate: a state that violates 1-safety fails
check 1 immediately, so the explored space is a subset of `{0,1}^10` and BFS
runs out of frontier after at most 1024 markings. This net reaches 16.

What varies by language is *when* the check runs. Go, Rust, Python, JavaScript
and Bash model-check at startup, every run. Lean states the claims as
`theorem`s discharged by `decide`: the kernel evaluates the BFS during
elaboration, and an unsafe model is a *compile error* — `main` cannot exist
unless the claims hold. That is the whole pitch of the form: the same
executable specification, but the trace is printed by a program that has
already been refused permission to be wrong.

**The Lean proof form is generated.** `lean/proof.lean` is emitted by
`tools/codegen -lang lean` from `model.json` (`make generate`), carries the
`DO NOT EDIT` header, and is gated by `//tools/codegen:codegen_up_to_date_test`
and `codegen_permutation_test` like the other generated sources — Bazel cannot
run `lean`, but it can tell that the theorems checked in are not the ones the
model implies. `make run-lean` / `make parity-native` are what actually check
the proofs. The generator derives the theorems from the model rather than
copying them:

| Theorem | Stated when | What codegen computes |
|---|---|---|
| `reachable_closed` | always | nothing — the BFS fuel is `2^n` for `n` places |
| `reachable_one_safe` | every place has `capacity: 1` (the loader rejects anything else) | nothing — claim 1 above |
| `invariant<k>_conserved`, one per basis vector | always | a basis of the left nullspace of the incidence matrix `C` (places × transitions): every integer `y` with `yᵀC = 0`, found by row-reducing `Cᵀ` over ℚ and scaling to primitive integer vectors. The theorem says `Σ y[p]·M[p]` equals its initial value on every reachable marking. Read and inhibitor arcs have no entry in `C` |
| `unique_deadlock` | the net is conflict-free (no two transitions consume one place) and codegen's own BFS finds exactly one terminal marking | the terminal marking, which the theorem names — claim 2 above |

The coffee machine has a 4-dimensional invariant space. Three of the four
vectors carry a `-1` on `Cup`: `PourCoffee` consumes `CoffeeInPot` and `Cup`
and produces nothing, so the only conserved quantities through it are
differences. The fourth, `Payment + Pending + Sent = 1`, is the one
semi-positive invariant — the token that travels the payment chain is never
created or destroyed. Weights are `Int` for exactly that reason.

Lean does not trust the Go linear algebra: it re-checks each invariant's
*consequence* on the enumerated state space. A generator that emitted a wrong
weight vector, a wrong terminal marking, or a BFS that did not close would
produce a file that fails to elaborate. The hand-written theorems the file
replaced — `reachable_one_safe`, `unique_deadlock`, `reachable_closed` — are
all regenerated with the same statements.
