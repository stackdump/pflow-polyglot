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

class Action(Enum):
    BOIL_WATER = auto()
    GRIND_BEANS = auto()
    BREW_COFFEE = auto()
    POUR_COFFEE = auto()
    SEND = auto()
    CREDIT = auto()

class Node:
    def __init__(self, place=None, transition=None):
        self.place = place
        self.transition = transition

class Arrow:
    def __init__(self, from_node, to_node):
        self.from_node = from_node
        self.to_node = to_node

class Guard:
    def __init__(self, from_node, to_node):
        self.from_node = from_node
        self.to_node = to_node

class CoffeeMachine:
    INITIAL_STATE = {State.WATER, State.COFFEE_BEANS, State.FILTER, State.CUP, State.PENDING}

    def __init__(self):
        self.state = set(CoffeeMachine.INITIAL_STATE)
        self.arrows = [
            Arrow(Node(place=State.WATER), Node(transition=Action.BOIL_WATER)),
            Arrow(Node(transition=Action.BOIL_WATER), Node(place=State.BOILED_WATER)),
            Arrow(Node(place=State.COFFEE_BEANS), Node(transition=Action.GRIND_BEANS)),
            Arrow(Node(transition=Action.GRIND_BEANS), Node(place=State.GROUND_COFFEE)),
            Arrow(Node(place=State.BOILED_WATER), Node(transition=Action.BREW_COFFEE)),
            Arrow(Node(place=State.GROUND_COFFEE), Node(transition=Action.BREW_COFFEE)),
            Arrow(Node(place=State.FILTER), Node(transition=Action.BREW_COFFEE)),
            Arrow(Node(transition=Action.BREW_COFFEE), Node(place=State.COFFEE_IN_POT)),
            Arrow(Node(place=State.COFFEE_IN_POT), Node(transition=Action.POUR_COFFEE)),
            Arrow(Node(place=State.CUP), Node(transition=Action.POUR_COFFEE)),
            Arrow(Node(place=State.PENDING), Node(transition=Action.SEND)),
            Arrow(Node(transition=Action.SEND), Node(place=State.SENT)),
            Arrow(Node(place=State.SENT), Node(transition=Action.CREDIT)),
            Arrow(Node(transition=Action.CREDIT), Node(place=State.PAYMENT)),
        ]
        self.guards = [
            Guard(Node(transition=Action.POUR_COFFEE), Node(place=State.PAYMENT))
        ]

    def can_execute(self, state, transition):
        can_execute, _, _ = self.prepare_transition(state, transition)
        return can_execute

    def execute_process(self):
        step = 0
        while True:
            any_executed = False
            for transition in Action:
                if self.execute_transition(transition):
                    any_executed = True
                    step += 1
                    print(f"Step #{step}: {transition} => {self.state}")
                    break
            if not any_executed:
                break

    def guard_fails(self, state, transition):
        for guard in self.guards:
            if guard.from_node.transition == transition and guard.to_node.place not in state:
                return True
            if guard.to_node.transition == transition and guard.from_node.place in state:
                return True
        return False

    def prepare_transition(self, state, transition):
        places_to_remove = []
        places_to_add = []

        if self.guard_fails(state, transition):
            return False, places_to_remove, places_to_add

        for arrow in self.arrows:
            if arrow.from_node.place and arrow.to_node.transition == transition:
                if arrow.from_node.place not in state:
                    return False, places_to_remove, places_to_add
                places_to_remove.append(arrow.from_node.place)
            if arrow.from_node.transition == transition and arrow.to_node.place:
                if arrow.to_node.place in state:
                    return False, places_to_remove, places_to_add
                places_to_add.append(arrow.to_node.place)

        return True, places_to_remove, places_to_add

    def execute_transition(self, transition):
        can_execute, places_to_remove, places_to_add = self.prepare_transition(self.state, transition)

        if not can_execute:
            return False

        for place in places_to_remove:
            self.state.remove(place)
        for place in places_to_add:
            self.state.add(place)
        return True

if __name__ == "__main__":
    cm = CoffeeMachine()
    cm.execute_process()