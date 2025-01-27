// FIXME: This is a work in progress. The code is not yet complete.

// Define States
const Water = (state) => state.Water || false;
const BoiledWater = (state) => state.BoiledWater || false;
const CoffeeBeans = (state) => state.CoffeeBeans || false;
const GroundCoffee = (state) => state.GroundCoffee || false;
const Filter = (state) => state.Filter || false;
const CoffeeInPot = (state) => state.CoffeeInPot || false;
const Pending = (state) => state.Pending || false;
const Sent = (state) => state.Sent || false;
const Payment = (state) => state.Payment || false;
const Cup = (state) => state.Cup || false;

// Transitions as Lambda Functions
const BoilWater = (state) =>
  Water(state) && !BoiledWater(state)
    ? (s) => ({
        ...s,
        Water: false,
        BoiledWater: true,
      })
    : (s) => s;

const GrindBeans = (state) =>
  CoffeeBeans(state) && !GroundCoffee(state)
    ? (s) => ({
        ...s,
        CoffeeBeans: false,
        GroundCoffee: true,
      })
    : (s) => s;

const BrewCoffee = (state) =>
  BoiledWater(state) && GroundCoffee(state) && Filter(state) && !CoffeeInPot(state)
    ? (s) => ({
        ...s,
        BoiledWater: false,
        GroundCoffee: false,
        Filter: false,
        CoffeeInPot: true,
      })
    : (s) => s;

const PourCoffee = (state) =>
  CoffeeInPot(state) && Cup(state)
    ? (s) => ({
        ...s,
        CoffeeInPot: false,
        Cup: false,
        Pending: true,
      })
    : (s) => s;

const Send = (state) =>
  Pending(state)
    ? (s) => ({
        ...s,
        Pending: false,
        Sent: true,
      })
    : (s) => s;

const Credit = (state) =>
  Sent(state)
    ? (s) => ({
        ...s,
        Sent: false,
        Payment: true,
      })
    : (s) => s;

// Guards as Lambda Functions
const Guard = (state, transition) => {
  const invalid = (s) => {
    // Example guard logic (e.g., you cannot PourCoffee without Payment)
    if (transition === PourCoffee && !Payment(s)) return true;
    return false;
  };
  return !invalid(state);
};

// Execute Transition (Higher-Order Function)
const executeTransition = (state, transition) =>
  Guard(state, transition) ? transition(state)(state) : state;

// Initial State
const initialState = {
  Water: true,
  CoffeeBeans: true,
  Filter: true,
  Cup: true,
  Pending: false,
  BoiledWater: false,
  GroundCoffee: false,
  CoffeeInPot: false,
  Sent: false,
  Payment: false,
};

// Sequence of Transitions (Lambda Composition)
const processCoffeeMachine = (state) => {
  const transitions = [BoilWater, GrindBeans, BrewCoffee, PourCoffee, Send, Credit];
  return transitions.reduce((currentState, transition) => {
    console.log("Current State:", currentState);
    const newState = executeTransition(currentState, transition);
    console.log("New State:", newState);
    return newState;
  }, state);
};

// Run the Coffee Machine
const finalState = processCoffeeMachine(initialState);
console.log("Final State:", finalState);
