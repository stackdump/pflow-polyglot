-- Contract form: the net is a public API surface. There is no scheduler and no
-- schedule — each transition is an entry point that either fires and appends to
-- the event log, or returns NotEnabled. The caller decides the order.
--
-- Haskell has no mutation, so the "contract instance" is threaded explicitly
-- and `Either NotEnabled CoffeeMachine` plays the role of revert-or-commit.
-- The observable behaviour is the same as solidity/contract.sol: an entry point
-- that is not enabled changes nothing.
--
-- See FORMS.md; output must match parity/trace.golden.
module Main (main) where

import Data.List (intercalate, sort)
import Data.Set (Set)
import qualified Data.Set as Set

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
  deriving (Show, Eq, Ord)

-- Why an entry point refused. The contract never partially applies.
data NotEnabled
  = MissingInput State
  | OutputAlreadyMarked State
  | GuardUnsatisfied State
  deriving (Show, Eq)

-- The marking plus the log of fired transitions.
data CoffeeMachine = CoffeeMachine
  { marked :: Set State,
    events :: [String]
  }

new :: CoffeeMachine
new =
  CoffeeMachine
    { marked = Set.fromList [Water, CoffeeBeans, Filter, Cup, Pending],
      events = []
    }

-- The contract's view function: the marked places, sorted by name.
marking :: CoffeeMachine -> String
marking = intercalate "," . sort . map show . Set.toList . marked

-- The enablement check every entry point runs first: all inputs marked, all
-- outputs clear, all guards satisfied.
requireEnabled :: CoffeeMachine -> [State] -> [State] -> [State] -> Either NotEnabled ()
requireEnabled cm inputs outputs guards
  | (p : _) <- filter (not . (`Set.member` marked cm)) inputs = Left (MissingInput p)
  | (p : _) <- filter (`Set.member` marked cm) outputs = Left (OutputAlreadyMarked p)
  | (p : _) <- filter (not . (`Set.member` marked cm)) guards = Left (GuardUnsatisfied p)
  | otherwise = Right ()

fire :: String -> [State] -> [State] -> [State] -> CoffeeMachine -> Either NotEnabled CoffeeMachine
fire name inputs outputs guards cm = do
  requireEnabled cm inputs outputs guards
  return
    cm
      { marked = Set.union (Set.fromList outputs) (Set.difference (marked cm) (Set.fromList inputs)),
        events = events cm ++ [name]
      }

boilWater :: CoffeeMachine -> Either NotEnabled CoffeeMachine
boilWater = fire "BoilWater" [Water] [BoiledWater] []

grindBeans :: CoffeeMachine -> Either NotEnabled CoffeeMachine
grindBeans = fire "GrindBeans" [CoffeeBeans] [GroundCoffee] []

brewCoffee :: CoffeeMachine -> Either NotEnabled CoffeeMachine
brewCoffee = fire "BrewCoffee" [BoiledWater, GroundCoffee, Filter] [CoffeeInPot] []

send :: CoffeeMachine -> Either NotEnabled CoffeeMachine
send = fire "Send" [Pending] [Sent] []

credit :: CoffeeMachine -> Either NotEnabled CoffeeMachine
credit = fire "Credit" [Sent] [Payment] []

-- Guarded on Payment, which it checks but does not consume.
pourCoffee :: CoffeeMachine -> Either NotEnabled CoffeeMachine
pourCoffee = fire "PourCoffee" [CoffeeInPot, Cup] [] [Payment]

-- The driver is the caller, not the machine. Calling these in any other order
-- returns Left rather than corrupting the marking.
calls :: [(String, CoffeeMachine -> Either NotEnabled CoffeeMachine)]
calls =
  [ ("BoilWater", boilWater),
    ("GrindBeans", grindBeans),
    ("BrewCoffee", brewCoffee),
    ("Send", send),
    ("Credit", credit),
    ("PourCoffee", pourCoffee)
  ]

run :: Int -> CoffeeMachine -> [(String, CoffeeMachine -> Either NotEnabled CoffeeMachine)] -> IO ()
run _ _ [] = return ()
run step cm ((name, call) : rest) =
  case call cm of
    Left _ -> run step cm rest
    Right next -> do
      putStrLn $ "Step #" ++ show (step + 1) ++ ": " ++ name ++ " => " ++ marking next
      run (step + 1) next rest

main :: IO ()
main = run 0 new calls
