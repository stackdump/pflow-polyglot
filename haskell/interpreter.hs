-- Interpreter form: the net is runtime data (arrows, guards) and a scheduler
-- searches for an enabled transition. See FORMS.md; output must match
-- parity/trace.golden.
module Main (main) where

import Data.List (intercalate, sort)
import Data.Set (Set)
import qualified Data.Set as Set

-- A place in the Petri net.
data State
  = Water
  | BoiledWater
  | CoffeeBeans
  | GroundCoffee
  | Filter
  | CoffeeInPot
  | Pending
  | Sent
  | Payment
  | Cup
  deriving (Show, Eq, Ord, Enum, Bounded)

-- A transition in the Petri net. Declaration order is the scheduler's search
-- order.
data Action
  = BoilWater
  | GrindBeans
  | BrewCoffee
  | PourCoffee
  | Send
  | Credit
  deriving (Show, Eq, Ord, Enum, Bounded)

-- A node is either a place or a transition. This is the distinction the
-- untyped implementations have to fake with a nullable field.
data Node
  = Place State
  | Transition Action
  deriving (Show, Eq)

data Arrow = Arrow Node Node

data Guard = Guard Node Node

-- The marking. The net is 1-safe, so a set is the whole state.
initialMarking :: Set State
initialMarking = Set.fromList [Water, CoffeeBeans, Filter, Cup, Pending]

arrows :: [Arrow]
arrows =
  [ Arrow (Place Water) (Transition BoilWater),
    Arrow (Transition BoilWater) (Place BoiledWater),
    Arrow (Place CoffeeBeans) (Transition GrindBeans),
    Arrow (Transition GrindBeans) (Place GroundCoffee),
    Arrow (Place BoiledWater) (Transition BrewCoffee),
    Arrow (Place GroundCoffee) (Transition BrewCoffee),
    Arrow (Place Filter) (Transition BrewCoffee),
    Arrow (Transition BrewCoffee) (Place CoffeeInPot),
    Arrow (Place CoffeeInPot) (Transition PourCoffee),
    Arrow (Place Cup) (Transition PourCoffee),
    Arrow (Place Pending) (Transition Send),
    Arrow (Transition Send) (Place Sent),
    Arrow (Place Sent) (Transition Credit),
    Arrow (Transition Credit) (Place Payment)
  ]

-- PourCoffee requires Payment to be marked, and does not consume it. The
-- direction matches model.json's inhibit arc.
guards :: [Guard]
guards = [Guard (Transition PourCoffee) (Place Payment)]

-- Canonical trace rendering: marked places, sorted by name, comma-joined.
-- Sorting on `show` rather than on the Ord instance is deliberate: Ord follows
-- declaration order, and the trace is lexicographic.
render :: Set State -> String
render = intercalate "," . sort . map show . Set.toList

guardFails :: Set State -> Action -> Bool
guardFails marking action = any fails guards
  where
    -- Transition -> Place: the place must be marked.
    fails (Guard (Transition t) (Place p)) = t == action && not (Set.member p marking)
    -- Place -> Transition: the place must be clear (an inhibitor).
    fails (Guard (Place p) (Transition t)) = t == action && Set.member p marking
    fails _ = False

inputsOf :: Action -> [State]
inputsOf action = [p | Arrow (Place p) (Transition t) <- arrows, t == action]

outputsOf :: Action -> [State]
outputsOf action = [p | Arrow (Transition t) (Place p) <- arrows, t == action]

-- Returns the marking after firing, or Nothing if the transition is not
-- enabled. Purity does the work the other languages need a prepare/execute
-- split for: nothing can be half-applied.
fire :: Set State -> Action -> Maybe (Set State)
fire marking action
  | guardFails marking action = Nothing
  | not (all (`Set.member` marking) inputs) = Nothing
  -- The net is 1-safe: firing into a marked place is not enabled.
  | any (`Set.member` marking) outputs = Nothing
  | otherwise =
      Just (Set.union (Set.fromList outputs) (Set.difference marking (Set.fromList inputs)))
  where
    inputs = inputsOf action
    outputs = outputsOf action

-- Fires the first enabled transition in declaration order until none is
-- enabled.
executeProcess :: Int -> Set State -> IO ()
executeProcess step marking =
  case [(action, next) | action <- [minBound .. maxBound], Just next <- [fire marking action]] of
    [] -> return ()
    ((action, next) : _) -> do
      putStrLn $ "Step #" ++ show (step + 1) ++ ": " ++ show action ++ " => " ++ render next
      executeProcess (step + 1) next

main :: IO ()
main = executeProcess 0 initialMarking
