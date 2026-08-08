-- Interpreter form: the net is runtime data (arrows, guards) and a scheduler
-- searches for an enabled transition. See FORMS.md; output must match
-- parity/trace.golden.
--
-- Lean 4 with no imports beyond the prelude: the marking is a `List State`
-- used as a set, which the 1-safe invariant makes honest. The one thing Lean
-- forces that the other functional implementations do not is `partial def` on
-- the scheduler — the loop runs until no transition is enabled, and that is
-- not a termination argument the compiler can find on its own.

-- A place in the Petri net.
inductive State where
  | Water
  | BoiledWater
  | CoffeeBeans
  | GroundCoffee
  | Filter
  | CoffeeInPot
  | Pending
  | Sent
  | Payment
  | Cup
  deriving DecidableEq, Repr

-- Place names as they appear in the trace. Written out rather than derived:
-- `Repr` output is a rendering decision, and the trace is a contract.
def State.name : State → String
  | .Water        => "Water"
  | .BoiledWater  => "BoiledWater"
  | .CoffeeBeans  => "CoffeeBeans"
  | .GroundCoffee => "GroundCoffee"
  | .Filter       => "Filter"
  | .CoffeeInPot  => "CoffeeInPot"
  | .Pending      => "Pending"
  | .Sent         => "Sent"
  | .Payment      => "Payment"
  | .Cup          => "Cup"

-- A transition in the Petri net.
inductive Action where
  | BoilWater
  | GrindBeans
  | BrewCoffee
  | PourCoffee
  | Send
  | Credit
  deriving DecidableEq, Repr

def Action.name : Action → String
  | .BoilWater  => "BoilWater"
  | .GrindBeans => "GrindBeans"
  | .BrewCoffee => "BrewCoffee"
  | .PourCoffee => "PourCoffee"
  | .Send       => "Send"
  | .Credit     => "Credit"

-- The scheduler's candidate order: every transition, sorted by name. This is
-- what implements the canonical scheduling policy (FORMS.md) — fire the enabled
-- transition whose name is lexicographically least.
--
-- Written out in sorted order rather than computed with a sort, because Lean's
-- prelude sort APIs have moved between versions. That makes this the one place
-- in the repo where the policy is maintained by hand rather than enforced:
-- keep the list sorted by name. Only 90 of the 720 possible orders produce
-- parity/trace.golden, and Lean is outside the Bazel gate, so nothing here will
-- catch a reordering except `make parity-native` on a box with Lean installed.
def Action.all : List Action :=
  [.BoilWater, .BrewCoffee, .Credit, .GrindBeans, .PourCoffee, .Send]

-- A node is either a place or a transition. This is the distinction the
-- untyped implementations have to fake with a nullable field.
inductive Node where
  | place : State → Node
  | transition : Action → Node
  deriving DecidableEq

structure Arrow where
  src : Node
  dst : Node

structure Guard where
  src : Node
  dst : Node

-- The marking. The net is 1-safe, so membership is the whole story and a list
-- is a set: nothing below ever adds a place that is already present.
abbrev Marking := List State

def initialMarking : Marking :=
  [.Water, .CoffeeBeans, .Filter, .Cup, .Pending]

def arrows : List Arrow :=
  [ ⟨.place .Water,         .transition .BoilWater⟩,
    ⟨.transition .BoilWater, .place .BoiledWater⟩,
    ⟨.place .CoffeeBeans,   .transition .GrindBeans⟩,
    ⟨.transition .GrindBeans, .place .GroundCoffee⟩,
    ⟨.place .BoiledWater,   .transition .BrewCoffee⟩,
    ⟨.place .GroundCoffee,  .transition .BrewCoffee⟩,
    ⟨.place .Filter,        .transition .BrewCoffee⟩,
    ⟨.transition .BrewCoffee, .place .CoffeeInPot⟩,
    ⟨.place .CoffeeInPot,   .transition .PourCoffee⟩,
    ⟨.place .Cup,           .transition .PourCoffee⟩,
    ⟨.place .Pending,       .transition .Send⟩,
    ⟨.transition .Send,     .place .Sent⟩,
    ⟨.place .Sent,          .transition .Credit⟩,
    ⟨.transition .Credit,   .place .Payment⟩ ]

-- PourCoffee requires Payment to be marked, and does not consume it. The
-- direction matches model.json's inhibit arc.
def guards : List Guard :=
  [ ⟨.transition .PourCoffee, .place .Payment⟩ ]

-- Insertion sort over strings. Written out rather than pulled from a library
-- so this file depends on nothing but the prelude; the trace's lexicographic
-- ordering is too load-bearing to leave to whatever `sort` happens to mean.
def insertSorted (x : String) : List String → List String
  | [] => [x]
  | y :: ys => if x < y then x :: y :: ys else y :: insertSorted x ys

def sortStrings (xs : List String) : List String :=
  xs.foldr insertSorted []

-- Canonical trace rendering: marked places, sorted by name, comma-joined.
-- Sorting on the name rather than on constructor order is deliberate: the
-- inductive's order is declaration order, and the trace is lexicographic.
def render (m : Marking) : String :=
  String.intercalate "," (sortStrings (m.map State.name))

def guardFails (m : Marking) (a : Action) : Bool :=
  guards.any fun g =>
    match g.src, g.dst with
    -- Transition -> Place: the place must be marked.
    | .transition t, .place p => t == a && !m.contains p
    -- Place -> Transition: the place must be clear (an inhibitor).
    | .place p, .transition t => t == a && m.contains p
    | _, _ => false

def inputsOf (a : Action) : List State :=
  arrows.filterMap fun ar =>
    match ar.src, ar.dst with
    | .place p, .transition t => if t == a then some p else none
    | _, _ => none

def outputsOf (a : Action) : List State :=
  arrows.filterMap fun ar =>
    match ar.src, ar.dst with
    | .transition t, .place p => if t == a then some p else none
    | _, _ => none

-- Returns the marking after firing, or `none` if the transition is not
-- enabled. Purity does the work the imperative implementations need a
-- prepare/execute split for: nothing can be half-applied.
def fire (m : Marking) (a : Action) : Option Marking :=
  let inputs := inputsOf a
  let outputs := outputsOf a
  if guardFails m a then none
  else if !inputs.all (fun p => m.contains p) then none
  -- The net is 1-safe: firing into a marked place is not enabled.
  else if outputs.any (fun p => m.contains p) then none
  else some ((m.filter fun p => !inputs.contains p) ++ outputs)

-- Fires the enabled transition that sorts first, until none is
-- enabled. `partial` because the termination argument is a property of this
-- net, not of the loop.
partial def executeProcess (step : Nat) (m : Marking) : IO Unit := do
  match Action.all.findSome? (fun a => (fire m a).map (fun next => (a, next))) with
  | none => pure ()
  | some (a, next) =>
      IO.println s!"Step #{step + 1}: {a.name} => {render next}"
      executeProcess (step + 1) next

def main : IO Unit :=
  executeProcess 0 initialMarking
