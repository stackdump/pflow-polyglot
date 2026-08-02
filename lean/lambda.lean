-- Lambda form: the net is a set of pure `Marking → Option Marking` functions
-- composed in a fixed schedule. No arrows, no guards list, no enablement
-- search — the arcs survive only as control flow inside each function.
--
-- Lean, like Haskell, is at home here: `Option Marking` *is* "(marking,
-- fired)", and the purity the imperative languages arrange by copying is the
-- default. Unlike the interpreter form, this one needs no `partial`: the
-- schedule is a finite list and the driver is structural recursion on it, so
-- termination is a fact the compiler checks rather than one we assert.
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

abbrev Marking := List State

def initialMarking : Marking :=
  [.Water, .CoffeeBeans, .Filter, .Cup, .Pending]

def insertSorted (x : String) : List String → List String
  | [] => [x]
  | y :: ys => if x < y then x :: y :: ys else y :: insertSorted x ys

def sortStrings (xs : List String) : List String :=
  xs.foldr insertSorted []

-- Canonical trace rendering: marked places, sorted by name, comma-joined.
def render (m : Marking) : String :=
  String.intercalate "," (sortStrings (m.map State.name))

-- Applies an arc pattern. The caller has already checked enablement.
def apply (remove add : List State) (m : Marking) : Marking :=
  (m.filter fun p => !remove.contains p) ++ add

def boilWater (m : Marking) : Option Marking :=
  if m.contains .Water && !m.contains .BoiledWater then
    some (apply [.Water] [.BoiledWater] m)
  else none

def grindBeans (m : Marking) : Option Marking :=
  if m.contains .CoffeeBeans && !m.contains .GroundCoffee then
    some (apply [.CoffeeBeans] [.GroundCoffee] m)
  else none

def brewCoffee (m : Marking) : Option Marking :=
  if [State.BoiledWater, .GroundCoffee, .Filter].all m.contains && !m.contains .CoffeeInPot then
    some (apply [.BoiledWater, .GroundCoffee, .Filter] [.CoffeeInPot] m)
  else none

def send (m : Marking) : Option Marking :=
  if m.contains .Pending && !m.contains .Sent then
    some (apply [.Pending] [.Sent] m)
  else none

def credit (m : Marking) : Option Marking :=
  if m.contains .Sent && !m.contains .Payment then
    some (apply [.Sent] [.Payment] m)
  else none

-- Carries the model's one guard: Payment must be present, and is not consumed.
def pourCoffee (m : Marking) : Option Marking :=
  if m.contains .Payment && [State.CoffeeInPot, .Cup].all m.contains then
    some (apply [.CoffeeInPot, .Cup] [] m)
  else none

-- The canonical firing order. Unlike the interpreter form, nothing here
-- searches for it — it is the author's claim about the model.
def schedule : List (String × (Marking → Option Marking)) :=
  [ ("BoilWater",  boilWater),
    ("GrindBeans", grindBeans),
    ("BrewCoffee", brewCoffee),
    ("Send",       send),
    ("Credit",     credit),
    ("PourCoffee", pourCoffee) ]

def run (step : Nat) (m : Marking) :
    List (String × (Marking → Option Marking)) → IO Unit
  | [] => pure ()
  | (name, transition) :: rest =>
    match transition m with
    | none => run step m rest
    | some next => do
        IO.println s!"Step #{step + 1}: {name} => {render next}"
        run (step + 1) next rest

def main : IO Unit :=
  run 0 initialMarking schedule
