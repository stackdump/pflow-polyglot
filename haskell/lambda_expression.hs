-- Define States as Lambda Variables
water = \state -> state "Water"
boiledWater = \state -> state "BoiledWater"
coffeeBeans = \state -> state "CoffeeBeans"
groundCoffee = \state -> state "GroundCoffee"
filter = \state -> state "Filter" -- REVIEW: consider renaming to filterCoffee
coffeeInPot = \state -> state "CoffeeInPot"
pending = \state -> state "Pending"
sent = \state -> state "Sent"
payment = \state -> state "Payment"
cup = \state -> state "Cup"

-- Define Transitions as Lambda Functions
boilWater = \state ->
  if water state && not (boiledWater state)
    then \key -> if key == "Water" then False else if key == "BoiledWater" then True else state key
    else state

grindBeans = \state ->
  if coffeeBeans state && not (groundCoffee state)
    then \key -> if key == "CoffeeBeans" then False else if key == "GroundCoffee" then True else state key
    else state

brewCoffee = \state ->
  if boiledWater state && groundCoffee state && filter state && not (coffeeInPot state)
    then \key ->
      if key == "BoiledWater" || key == "GroundCoffee" || key == "Filter"
        then False
        else if key == "CoffeeInPot"
          then True
          else state key
    else state

pourCoffee = \state ->
  if coffeeInPot state && cup state
    then \key -> if key == "CoffeeInPot" || key == "Cup" then False else if key == "Pending" then True else state key
    else state

send = \state ->
  if pending state
    then \key -> if key == "Pending" then False else if key == "Sent" then True else state key
    else state

credit = \state ->
  if sent state
    then \key -> if key == "Sent" then False else if key == "Payment" then True else state key
    else state

-- Define Guards as Lambda Functions
guardFails = \state transition ->
  let guardPourCoffee = transition == pourCoffee && not (payment state)
   in guardPourCoffee

-- Transition Execution Logic as Lambda Functions
executeTransition = \state transition ->
  if guardFails state transition
    then state
    else transition state

-- Define the Initial State
initialState = \key ->
  case key of
    "Water" -> True
    "CoffeeBeans" -> True
    "Filter" -> True
    "Cup" -> True
    "Pending" -> True
    _ -> False

-- Execute All Transitions
executeProcess = \state transitions ->
  let loop currentState step =
        let executableTransitions = filter (\t -> not (guardFails currentState t)) transitions
         in case executableTransitions of
              [] -> currentState
              (transition : _) ->
                let newState = executeTransition currentState transition
                 in loop newState (step + 1)
   in loop state 0

-- Main Execution
main = do
  let finalState = executeProcess initialState [boilWater, grindBeans, brewCoffee, pourCoffee, send, credit]
  putStrLn $ "Final State: " ++ show (map (\key -> (key, finalState key)) ["Water", "BoiledWater", "CoffeeBeans", "GroundCoffee", "Filter", "CoffeeInPot", "Pending", "Sent", "Payment", "Cup"])
