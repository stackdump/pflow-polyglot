from enum import Enum, auto

class State(Enum):
    WATER = auto()
    BOILED_WATER = auto()
    COFFEE_BEANS = auto()
    GROUND_COFFEE = auto()
    FILTER = auto()
    COFFEE_IN_POT = auto()
    PENDING = auto()
    SENT = auto()
    PAYMENT = auto()
    CUP = auto()

# CoffeeMachineState is a dictionary of States to bool
CoffeeMachineState = dict

# Transition Functions
def boil_water(state: CoffeeMachineState) -> CoffeeMachineState:
    if state.get(State.WATER) and not state.get(State.BOILED_WATER):
        state[State.BOILED_WATER] = True
        state[State.WATER] = False
    return state

def grind_coffee(state: CoffeeMachineState) -> CoffeeMachineState:
    if state.get(State.COFFEE_BEANS) and not state.get(State.GROUND_COFFEE):
        state[State.GROUND_COFFEE] = True
        state[State.COFFEE_BEANS] = False
    return state

def brew_coffee(state: CoffeeMachineState) -> CoffeeMachineState:
    if state.get(State.BOILED_WATER) and state.get(State.GROUND_COFFEE) and state.get(State.FILTER):
        state[State.COFFEE_IN_POT] = True
        state[State.BOILED_WATER] = False
        state[State.GROUND_COFFEE] = False
        state[State.FILTER] = False
    return state

def send_order(state: CoffeeMachineState) -> CoffeeMachineState:
    if state.get(State.PENDING) and not state.get(State.SENT):
        state[State.SENT] = True
        state[State.PENDING] = False
    return state

def make_payment(state: CoffeeMachineState) -> CoffeeMachineState:
    if state.get(State.SENT) and not state.get(State.PAYMENT):
        state[State.PAYMENT] = True
        state[State.SENT] = False
    return state

def serve_coffee(state: CoffeeMachineState) -> CoffeeMachineState:
    if state.get(State.COFFEE_IN_POT) and state.get(State.PAYMENT) and not state.get(State.CUP):
        state[State.CUP] = True
        state[State.COFFEE_IN_POT] = False
        state[State.PAYMENT] = False
    return state

# Example usage
if __name__ == "__main__":
    state = {
        State.WATER: True,
        State.BOILED_WATER: False,
        State.COFFEE_BEANS: False,
        State.GROUND_COFFEE: False,
        State.FILTER: False,
        State.COFFEE_IN_POT: False,
        State.PENDING: False,
        State.SENT: False,
        State.PAYMENT: False,
        State.CUP: False,
    }
    state = boil_water(state)
    state = grind_coffee(state)
    state = brew_coffee(state)
    state = send_order(state)
    state = make_payment(state)
    state = serve_coffee(state)
    print(state)