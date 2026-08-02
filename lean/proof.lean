-- Proof form: the net is a claim about every reachable marking, and the claim
-- is discharged before the program is allowed to exist. See FORMS.md; output
-- must match parity/trace.golden.
--
-- The marking here is a *multiset* — a count per place — and enablement is
-- plain P/T semantics with no `capacity: 1` clause. The two theorems at the
-- bottom are checked by `decide`: the kernel evaluates the breadth-first
-- search over the reachable state space (16 markings) during elaboration.
-- Make the net unsafe — say, add a second arc producing into Payment — and
-- this file stops compiling. The other languages' proof forms run the same
-- check at startup; Lean runs it before `main` can be defined.

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

def State.all : List State :=
  [.Water, .BoiledWater, .CoffeeBeans, .GroundCoffee, .Filter,
   .CoffeeInPot, .Pending, .Sent, .Payment, .Cup]

-- The multiset marking: how many tokens each place holds. Association by
-- position into State.all keeps it a plain List Nat, which is what lets
-- `decide` evaluate everything below inside the kernel.
abbrev Marking := List Nat

def indexOf (p : State) : Nat :=
  (State.all.findIdx? (· == p)).getD 0

def count (m : Marking) (p : State) : Nat :=
  m.getD (indexOf p) 0

def initialMarking : Marking :=
  State.all.map fun p =>
    if [State.Water, .CoffeeBeans, .Filter, .Cup, .Pending].contains p then 1 else 0

-- One transition: inputs consumed, outputs produced, guards read but not
-- consumed. The same shape the contract form's entry points take.
structure Transition where
  name    : String
  inputs  : List State
  outputs : List State
  guards  : List State

-- Scheduler search order — the interpreter form's declaration order.
def transitions : List Transition :=
  [ ⟨"BoilWater",  [.Water], [.BoiledWater], []⟩,
    ⟨"GrindBeans", [.CoffeeBeans], [.GroundCoffee], []⟩,
    ⟨"BrewCoffee", [.BoiledWater, .GroundCoffee, .Filter], [.CoffeeInPot], []⟩,
    ⟨"PourCoffee", [.CoffeeInPot, .Cup], [], [.Payment]⟩,
    ⟨"Send",       [.Pending], [.Sent], []⟩,
    ⟨"Credit",     [.Sent], [.Payment], []⟩ ]

-- Plain P/T enablement: inputs and guards marked. Deliberately no
-- "outputs clear" clause — that the clause is never needed is theorem 1.
def enabled (m : Marking) (t : Transition) : Bool :=
  t.inputs.all (fun p => count m p ≥ 1) && t.guards.all (fun p => count m p ≥ 1)

def fireCounts (m : Marking) (t : Transition) : Marking :=
  State.all.map fun p =>
    count m p - (if t.inputs.contains p then 1 else 0)
              + (if t.outputs.contains p then 1 else 0)

def successors (m : Marking) : List Marking :=
  (transitions.filter (enabled m ·)).map (fireCounts m)

-- Breadth-first search over the reachable state space. The frontier bound is
-- 2^10: past it, some marking must exceed one token, and theorem 1 has
-- already failed. This net reaches 16 markings; the fuel is never the limit.
def explore : Nat → List Marking → List Marking → List Marking
  | 0, seen, _ => seen
  | _ + 1, seen, [] => seen
  | fuel + 1, seen, m :: frontier =>
      let fresh := (successors m).filter (fun n => !seen.contains n)
      explore fuel (seen ++ fresh) (frontier ++ fresh)

def reachable : List Marking :=
  explore 1024 [initialMarking] [initialMarking]

def oneSafe (m : Marking) : Bool :=
  m.all (· ≤ 1)

def isDeadlock (m : Marking) : Bool :=
  transitions.all (fun t => !enabled m t)

def finalMarking : Marking :=
  State.all.map fun p => if p == State.Payment then 1 else 0

-- Theorem 1: 1-safety is structural. No reachable marking holds two tokens
-- anywhere, even though nothing above stops a transition firing into a marked
-- place. This is what licenses the set representation every other form uses.
theorem reachable_one_safe : reachable.all oneSafe = true := by decide

-- Theorem 2: the outcome is confluent. The net is conflict-free, so every
-- maximal firing sequence stops at the same marking — and it is {Payment}.
-- The golden trace's final line is the only place the net can stop.
theorem unique_deadlock :
    (reachable.filter isDeadlock) = [finalMarking] := by decide

-- The BFS closed: every successor of a reachable marking was reached, so the
-- theorems above quantify over the whole state space, not a fuel-truncated
-- prefix of it.
theorem reachable_closed :
    reachable.all (fun m => (successors m).all (reachable.contains ·)) = true := by
  decide

-- What remains is the interpreter form's scheduler, running on a net the
-- compiler has already checked.

def insertSorted (x : String) : List String → List String
  | [] => [x]
  | y :: ys => if x < y then x :: y :: ys else y :: insertSorted x ys

def sortStrings (xs : List String) : List String :=
  xs.foldr insertSorted []

-- Canonical trace rendering: marked places, sorted by name, comma-joined.
def render (m : Marking) : String :=
  String.intercalate "," (sortStrings ((State.all.filter (count m · ≥ 1)).map State.name))

partial def executeProcess (step : Nat) (m : Marking) : IO Unit := do
  match transitions.find? (enabled m ·) with
  | none => pure ()
  | some t =>
      let next := fireCounts m t
      IO.println s!"Step #{step + 1}: {t.name} => {render next}"
      executeProcess (step + 1) next

def main : IO Unit :=
  executeProcess 0 initialMarking
