-- Define States as an Algebraic Data Type
data State = Water | BoiledWater | CoffeeBeans | GroundCoffee | Filter | CoffeeInPot | Pending | Sent | Payment | Cup
  deriving (Show, Eq)

-- Define the Coffee Machine State
type CoffeeMachineState = [State]

-- Define Transitions as Functions
boilWater :: CoffeeMachineState -> CoffeeMachineState
boilWater state
  | Water `elem` state && BoiledWater `notElem` state = BoiledWater : filter (/= Water) state
  | otherwise = state

grindBeans :: CoffeeMachineState -> CoffeeMachineState
grindBeans state
  | CoffeeBeans `elem` state && GroundCoffee `notElem` state = GroundCoffee : filter (/= CoffeeBeans) state
  | otherwise = state

brewCoffee :: CoffeeMachineState -> CoffeeMachineState
brewCoffee state
  | BoiledWater `elem` state && GroundCoffee `elem` state && Filter `elem` state && CoffeeInPot `notElem` state =
      CoffeeInPot : filter (`notElem` [BoiledWater, GroundCoffee, Filter]) state
  | otherwise = state

pourCoffee :: CoffeeMachineState -> CoffeeMachineState
pourCoffee state
  | CoffeeInPot `elem` state && Cup `elem` state = Pending : filter (`notElem` [CoffeeInPot, Cup]) state
  | otherwise = state

send :: CoffeeMachineState -> CoffeeMachineState
send state
  | Pending `elem` state = Sent : filter (/= Pending) state
  | otherwise = state

credit :: CoffeeMachineState -> CoffeeMachineState
credit state
  | Sent `elem` state = Payment : filter (/= Sent) state
  | otherwise = state

-- Define the Initial State
initialState :: CoffeeMachineState
initialState = [Water, CoffeeBeans, Filter, Cup, Pending]

-- Execute All Transitions
executeProcess :: CoffeeMachineState -> [CoffeeMachineState -> CoffeeMachineState] -> CoffeeMachineState
executeProcess state transitions = foldl (\s t -> t s) state transitions

-- Main Execution
main :: IO ()
main = do
  let finalState = executeProcess initialState [boilWater, grindBeans, brewCoffee, pourCoffee, send, credit]
  putStrLn $ "Final State: " ++ show finalState