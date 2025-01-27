// Define States as an Enum
#[derive(Debug, PartialEq, Eq, Clone)]
enum State {
    Water,
    BoiledWater,
    CoffeeBeans,
    GroundCoffee,
    Filter,
    CoffeeInPot,
    Pending,
    Sent,
    Payment,
    Cup,
}

// Define the Coffee Machine State
type CoffeeMachineState = Vec<State>;

// Define Transitions as Functions
fn boil_water(state: CoffeeMachineState) -> CoffeeMachineState {
    if state.contains(&State::Water) && !state.contains(&State::BoiledWater) {
        let mut new_state = state.into_iter().filter(|s| s != &State::Water).collect::<Vec<_>>();
        new_state.push(State::BoiledWater);
        new_state
    } else {
        state
    }
}

fn grind_beans(state: CoffeeMachineState) -> CoffeeMachineState {
    if state.contains(&State::CoffeeBeans) && !state.contains(&State::GroundCoffee) {
        let mut new_state = state.into_iter().filter(|s| s != &State::CoffeeBeans).collect::<Vec<_>>();
        new_state.push(State::GroundCoffee);
        new_state
    } else {
        state
    }
}

fn brew_coffee(state: CoffeeMachineState) -> CoffeeMachineState {
    if state.contains(&State::BoiledWater)
        && state.contains(&State::GroundCoffee)
        && state.contains(&State::Filter)
        && !state.contains(&State::CoffeeInPot)
    {
        let mut new_state = state
            .into_iter()
            .filter(|s| ![State::BoiledWater, State::GroundCoffee, State::Filter].contains(s))
            .collect::<Vec<_>>();
        new_state.push(State::CoffeeInPot);
        new_state
    } else {
        state
    }
}

fn pour_coffee(state: CoffeeMachineState) -> CoffeeMachineState {
    if state.contains(&State::CoffeeInPot) && state.contains(&State::Cup) {
        let mut new_state = state
            .into_iter()
            .filter(|s| ![State::CoffeeInPot, State::Cup].contains(s))
            .collect::<Vec<_>>();
        new_state.push(State::Pending);
        new_state
    } else {
        state
    }
}

fn send(state: CoffeeMachineState) -> CoffeeMachineState {
    if state.contains(&State::Pending) {
        let mut new_state = state.into_iter().filter(|s| s != &State::Pending).collect::<Vec<_>>();
        new_state.push(State::Sent);
        new_state
    } else {
        state
    }
}

fn credit(state: CoffeeMachineState) -> CoffeeMachineState {
    if state.contains(&State::Sent) {
        let mut new_state = state.into_iter().filter(|s| s != &State::Sent).collect::<Vec<_>>();
        new_state.push(State::Payment);
        new_state
    } else {
        state
    }
}

// Define the Initial State
fn initial_state() -> CoffeeMachineState {
    vec![
        State::Water,
        State::CoffeeBeans,
        State::Filter,
        State::Cup,
        State::Pending,
    ]
}

// Execute All Transitions
fn execute_process(
    state: CoffeeMachineState,
    transitions: Vec<fn(CoffeeMachineState) -> CoffeeMachineState>,
) -> CoffeeMachineState {
    transitions.into_iter().fold(state, |s, t| t(s))
}

// Main Execution
fn main() {
    let initial_state = initial_state();
    let final_state = execute_process(
        initial_state,
        vec![boil_water, grind_beans, brew_coffee, pour_coffee, send, credit],
    );
    println!("Final State: {:?}", final_state);
}
