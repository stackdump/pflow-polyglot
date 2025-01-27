{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DeriveAnyClass #-}

import Data.Set (Set)
import qualified Data.Set as Set
import GHC.Generics (Generic)
import Data.List (find)

-- Represents a place in the Petri net.
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
  deriving (Show, Eq, Ord, Enum, Bounded, Generic)

-- Represents a transition in the Petri net.
data Action
  = BoilWater
  | GrindBeans
  | BrewCoffee
  | PourCoffee
  | Send
  | Credit
  deriving (Show, Eq, Ord, Enum, Bounded, Generic)

-- Represents a node in the Petri net, which can be either a Place or a Transition.
data Node
  = Place State
  | Transition Action
  deriving (Show, Eq, Ord, Generic)

-- Represents an arc in the Petri net.
data Arrow = Arrow
  { from :: Node,
    to :: Node
  }
  deriving (Show, Eq, Generic)

-- Represents a guard in the Petri net.
data Guard = Guard
  { gFrom :: Node,
    gTo :: Node
  }
  deriving (Show, Eq, Generic)

-- Represents the CoffeeMachine.
data CoffeeMachine = CoffeeMachine
  { state :: Set State,
    arrows :: [Arrow],
    guards :: [Guard]
  }
  deriving (Show, Generic)

-- Initial state of the CoffeeMachine.
initialState :: Set State
initialState = Set.fromList [Water, CoffeeBeans, Filter, Cup, Pending]

-- Define the arrows (arcs) of the CoffeeMachine.
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

-- Define the guards of the CoffeeMachine.
guards :: [Guard]
guards = [Guard (Transition PourCoffee) (Place Payment)]

-- Create a new CoffeeMachine.
newCoffeeMachine :: CoffeeMachine
newCoffeeMachine =
  CoffeeMachine
    { state = initialState,
      arrows = arrows,
      guards = guards
    }

-- Check if a guard fails for a transition.
guardFails :: CoffeeMachine -> Action -> Bool
guardFails cm action =
  any
    (\(Guard (Place from) (Transition to)) -> to == action && Set.member from (state cm))
    (guards cm)

-- Prepare a transition by checking if it's executable and identifying state changes.
prepareTransition :: CoffeeMachine -> Action -> (Bool, [State], [State])
prepareTransition cm action =
  if guardFails cm action
    then (False, [], [])
    else foldl checkArc (True, [], []) (arrows cm)
  where
    checkArc (canExecute, toRemove, toAdd) (Arrow fromNode toNode) =
      case (fromNode, toNode) of
        (Place p, Transition t) | t == action && not (Set.member p (state cm)) -> (False, [], [])
        (Place p, Transition t) | t == action -> (canExecute, p : toRemove, toAdd)
        (Transition t, Place p) | t == action && Set.member p (state cm) -> (False, [], [])
        (Transition t, Place p) | t == action -> (canExecute, toRemove, p : toAdd)
        _ -> (canExecute, toRemove, toAdd)

-- Execute a transition if possible.
executeTransition :: CoffeeMachine -> Action -> CoffeeMachine
executeTransition cm action =
  let (canExecute, toRemove, toAdd) = prepareTransition cm action
   in if canExecute
        then
          cm
            { state = Set.union (Set.fromList toAdd) (Set.difference (state cm) (Set.fromList toRemove))
            }
        else cm

-- Execute all possible transitions in the Petri net process.
executeProcess :: CoffeeMachine -> IO ()
executeProcess cm = loop cm 0
  where
    loop machine step = do
      let executableTransitions = filter (canExecute machine) [minBound .. maxBound]
      case executableTransitions of
        [] -> return ()
        (action : _) -> do
          let newMachine = executeTransition machine action
          putStrLn $ "Step #" ++ show (step + 1) ++ ": " ++ show action ++ " => " ++ show (state newMachine)
          loop newMachine (step + 1)
    canExecute machine action =
      let (canExecute, _, _) = prepareTransition machine action
       in canExecute

-- Main function.
main :: IO ()
main = do
  let cm = newCoffeeMachine
  executeProcess cm
