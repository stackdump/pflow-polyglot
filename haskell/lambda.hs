-- Lambda form: the net is a set of pure Marking -> Maybe Marking functions
-- composed in a fixed schedule. No arrows, no guards list, no enablement
-- search — the arcs survive only as control flow inside each function.
--
-- Haskell is where this form is most at home: `Maybe Marking` *is*
-- "(marking, fired)", and the purity the other languages have to arrange by
-- copying is free.
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

type Marking = Set State

initialMarking :: Marking
initialMarking = Set.fromList [Water, CoffeeBeans, Filter, Cup, Pending]

-- Canonical trace rendering: marked places, sorted by name, comma-joined.
render :: Marking -> String
render = intercalate "," . sort . map show . Set.toList

-- Applies an arc pattern. The caller has already checked enablement.
apply :: [State] -> [State] -> Marking -> Marking
apply remove add marking =
  Set.union (Set.fromList add) (Set.difference marking (Set.fromList remove))

boilWater :: Marking -> Maybe Marking
boilWater m
  | Set.member Water m && not (Set.member BoiledWater m) = Just (apply [Water] [BoiledWater] m)
  | otherwise = Nothing

grindBeans :: Marking -> Maybe Marking
grindBeans m
  | Set.member CoffeeBeans m && not (Set.member GroundCoffee m) =
      Just (apply [CoffeeBeans] [GroundCoffee] m)
  | otherwise = Nothing

brewCoffee :: Marking -> Maybe Marking
brewCoffee m
  | all (`Set.member` m) [BoiledWater, GroundCoffee, Filter] && not (Set.member CoffeeInPot m) =
      Just (apply [BoiledWater, GroundCoffee, Filter] [CoffeeInPot] m)
  | otherwise = Nothing

send :: Marking -> Maybe Marking
send m
  | Set.member Pending m && not (Set.member Sent m) = Just (apply [Pending] [Sent] m)
  | otherwise = Nothing

credit :: Marking -> Maybe Marking
credit m
  | Set.member Sent m && not (Set.member Payment m) = Just (apply [Sent] [Payment] m)
  | otherwise = Nothing

-- Carries the model's one guard: Payment must be present, and is not consumed.
pourCoffee :: Marking -> Maybe Marking
pourCoffee m
  | Set.member Payment m && all (`Set.member` m) [CoffeeInPot, Cup] =
      Just (apply [CoffeeInPot, Cup] [] m)
  | otherwise = Nothing

-- The canonical firing order. Unlike the interpreter form, nothing here
-- searches for it — it is the author's claim about the model.
schedule :: [(String, Marking -> Maybe Marking)]
schedule =
  [ ("BoilWater", boilWater),
    ("GrindBeans", grindBeans),
    ("BrewCoffee", brewCoffee),
    ("Send", send),
    ("Credit", credit),
    ("PourCoffee", pourCoffee)
  ]

run :: Int -> Marking -> [(String, Marking -> Maybe Marking)] -> IO ()
run _ _ [] = return ()
run step marking ((name, transition) : rest) =
  case transition marking of
    Nothing -> run step marking rest
    Just next -> do
      putStrLn $ "Step #" ++ show (step + 1) ++ ": " ++ name ++ " => " ++ render next
      run (step + 1) next rest

main :: IO ()
main = run 0 initialMarking schedule
