-- Contract form: the net is a public API surface. There is no scheduler and no
-- schedule — each transition is an entry point that either fires and appends to
-- the event log, or returns NotEnabled. The caller decides the order.
--
-- Lean has no mutation, so the "contract instance" is threaded explicitly and
-- `Except NotEnabled CoffeeMachine` plays the role of revert-or-commit. The
-- observable behaviour is the same as solidity/contract.sol: an entry point
-- that is not enabled changes nothing. Lean makes that claim structurally —
-- `requireEnabled` returns before any `CoffeeMachine` is constructed, so there
-- is no state to roll back.
--
-- See FORMS.md; output must match parity/trace.golden.

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

-- Why an entry point refused. The contract never partially applies.
inductive NotEnabled where
  | missingInput : State → NotEnabled
  | outputAlreadyMarked : State → NotEnabled
  | guardUnsatisfied : State → NotEnabled

def NotEnabled.describe : NotEnabled → String
  | .missingInput p        => s!"missing input {p.name}"
  | .outputAlreadyMarked p => s!"output already marked {p.name}"
  | .guardUnsatisfied p    => s!"guard unsatisfied {p.name}"

-- The marking plus the log of fired transitions.
structure CoffeeMachine where
  marked : List State
  events : List String

def CoffeeMachine.new : CoffeeMachine :=
  { marked := [.Water, .CoffeeBeans, .Filter, .Cup, .Pending], events := [] }

def insertSorted (x : String) : List String → List String
  | [] => [x]
  | y :: ys => if x < y then x :: y :: ys else y :: insertSorted x ys

def sortStrings (xs : List String) : List String :=
  xs.foldr insertSorted []

-- The contract's view function: the marked places, sorted by name.
def CoffeeMachine.marking (cm : CoffeeMachine) : String :=
  String.intercalate "," (sortStrings (cm.marked.map State.name))

-- The enablement check every entry point runs first: all inputs marked, all
-- outputs clear, all guards satisfied.
def requireEnabled (cm : CoffeeMachine) (inputs outputs guards : List State) :
    Except NotEnabled Unit :=
  match inputs.find? (fun p => !cm.marked.contains p) with
  | some p => .error (.missingInput p)
  | none =>
    match outputs.find? (fun p => cm.marked.contains p) with
    | some p => .error (.outputAlreadyMarked p)
    | none =>
      match guards.find? (fun p => !cm.marked.contains p) with
      | some p => .error (.guardUnsatisfied p)
      | none => .ok ()

def fire (name : String) (inputs outputs guards : List State) (cm : CoffeeMachine) :
    Except NotEnabled CoffeeMachine := do
  requireEnabled cm inputs outputs guards
  return { marked := (cm.marked.filter fun p => !inputs.contains p) ++ outputs,
           events := cm.events ++ [name] }

def boilWater : CoffeeMachine → Except NotEnabled CoffeeMachine :=
  fire "BoilWater" [.Water] [.BoiledWater] []

def grindBeans : CoffeeMachine → Except NotEnabled CoffeeMachine :=
  fire "GrindBeans" [.CoffeeBeans] [.GroundCoffee] []

def brewCoffee : CoffeeMachine → Except NotEnabled CoffeeMachine :=
  fire "BrewCoffee" [.BoiledWater, .GroundCoffee, .Filter] [.CoffeeInPot] []

def send : CoffeeMachine → Except NotEnabled CoffeeMachine :=
  fire "Send" [.Pending] [.Sent] []

def credit : CoffeeMachine → Except NotEnabled CoffeeMachine :=
  fire "Credit" [.Sent] [.Payment] []

-- Guarded on Payment, which it checks but does not consume.
def pourCoffee : CoffeeMachine → Except NotEnabled CoffeeMachine :=
  fire "PourCoffee" [.CoffeeInPot, .Cup] [] [.Payment]

-- The driver is the caller, not the machine. Calling these in any other order
-- returns `error` rather than corrupting the marking.
def calls : List (String × (CoffeeMachine → Except NotEnabled CoffeeMachine)) :=
  [ ("BoilWater",  boilWater),
    ("GrindBeans", grindBeans),
    ("BrewCoffee", brewCoffee),
    ("Send",       send),
    ("Credit",     credit),
    ("PourCoffee", pourCoffee) ]

def run (step : Nat) (cm : CoffeeMachine) :
    List (String × (CoffeeMachine → Except NotEnabled CoffeeMachine)) → IO Unit
  | [] => pure ()
  | (name, call) :: rest =>
    match call cm with
    | .error _ => run step cm rest
    | .ok next => do
        IO.println s!"Step #{step + 1}: {name} => {next.marking}"
        run (step + 1) next rest

def main : IO Unit :=
  run 0 CoffeeMachine.new calls
