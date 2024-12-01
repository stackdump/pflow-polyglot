use std::collections::HashSet;
use strum::IntoEnumIterator;
use strum_macros::EnumIter;

/// Represents a place in the Petri net.
#[derive(Debug, Clone, EnumIter, Eq, PartialEq, Hash)]
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

/// Represents a transition in the Petri net.
#[derive(Debug, Clone, Eq, PartialEq, Hash, EnumIter)]
enum Action {
    BoilWater,
    GrindBeans,
    BrewCoffee,
    PourCoffee,
    Send,
    Credit,
}

/// Represents a node in the Petri net, which can be either a Place or a Transition.
#[derive(Debug, Clone)]
enum Node {
    Place(State),
    Transition(Action),
}

/// Represents an arc in the Petri net.
#[derive(Debug, Clone)]
struct Arrow {
    from: Node,
    to: Node,
}

#[derive(Debug, Clone)]
struct Guard {
    from: Node,
    to: Node,
}

#[derive(Debug, Clone)]
struct CoffeeMachine {
    state: HashSet<State>,
    arrows: Vec<Arrow>,
    guards: Vec<Guard>,
}

impl CoffeeMachine {
    const INITIAL_STATE: [State; 5] = [
        State::Water,
        State::CoffeeBeans,
        State::Filter,
        State::Cup,
        State::Pending,
    ];

    fn new() -> Self {
        let state: HashSet<State> = CoffeeMachine::INITIAL_STATE.iter().cloned().collect();

        let arrows = vec![
            Arrow {
                from: Node::Place(State::Water),
                to: Node::Transition(Action::BoilWater),
            },
            Arrow {
                from: Node::Transition(Action::BoilWater),
                to: Node::Place(State::BoiledWater),
            },
            Arrow {
                from: Node::Place(State::CoffeeBeans),
                to: Node::Transition(Action::GrindBeans),
            },
            Arrow {
                from: Node::Transition(Action::GrindBeans),
                to: Node::Place(State::GroundCoffee),
            },
            Arrow {
                from: Node::Place(State::BoiledWater),
                to: Node::Transition(Action::BrewCoffee),
            },
            Arrow {
                from: Node::Place(State::GroundCoffee),
                to: Node::Transition(Action::BrewCoffee),
            },
            Arrow {
                from: Node::Place(State::Filter),
                to: Node::Transition(Action::BrewCoffee),
            },
            Arrow {
                from: Node::Transition(Action::BrewCoffee),
                to: Node::Place(State::CoffeeInPot),
            },
            Arrow {
                from: Node::Place(State::CoffeeInPot),
                to: Node::Transition(Action::PourCoffee),
            },
            Arrow {
                from: Node::Place(State::Cup),
                to: Node::Transition(Action::PourCoffee),
            },
            Arrow {
                from: Node::Place(State::Pending),
                to: Node::Transition(Action::Send),
            },
            Arrow {
                from: Node::Transition(Action::Send),
                to: Node::Place(State::Sent),
            },
            Arrow {
                from: Node::Place(State::Sent),
                to: Node::Transition(Action::Credit),
            },
            Arrow {
                from: Node::Transition(Action::Credit),
                to: Node::Place(State::Payment),
            },
        ];

        let guards = vec![Guard {
            from: Node::Transition(Action::PourCoffee),
            to: Node::Place(State::Payment),
        }];

        CoffeeMachine {
            state,
            arrows,
            guards,
        }
    }
}

trait StateMachine {
    #[allow(dead_code)]
    fn can_execute(&self, transition: &Action) -> bool;
    fn execute_process(&mut self);
    fn guard_fails(&self, state: &HashSet<State>, transition: &Action) -> bool;
    fn prepare_transition(
        &self,
        state: &HashSet<State>,
        transition: &Action,
    ) -> (bool, Vec<State>, Vec<State>);
    fn execute_transition(&mut self, transition: Action) -> bool;
}

impl StateMachine for CoffeeMachine {

    #[allow(dead_code)]
    fn can_execute(&self, transition: &Action) -> bool {
        let (can_execute, _, _) = self.prepare_transition(&self.state, &transition);
        can_execute
    }

    fn execute_process(&mut self) {
        let mut i = 0;
        loop {
            let mut any_executed = false;
            for transition in Action::iter() {
                if self.execute_transition(transition.clone()) {
                    any_executed = true;
                    i += 1;
                    println!("Step #{}: {:?} => {:?}", i, transition, self.state);
                    break;
                }
            }
            if !any_executed {
                break;
            }
        }
    }

    fn guard_fails(&self, state: &HashSet<State>, transition: &Action) -> bool {
        for guard in &self.guards {
            match (&guard.from, &guard.to) {
                (Node::Place(from), Node::Transition(to))
                    if to == transition && state.contains(from) =>
                {
                    return true;
                }
                (Node::Transition(from), Node::Place(to))
                    if from == transition && !state.contains(to) =>
                {
                    return true;
                }
                _ => continue,
            }
        }
        false
    }

    fn prepare_transition(
        &self,
        state: &HashSet<State>,
        transition: &Action,
    ) -> (bool, Vec<State>, Vec<State>) {
        let mut places_to_remove = vec![];
        let mut places_to_add = vec![];

        if self.guard_fails(state, transition) {
            return (false, places_to_remove, places_to_add);
        }

        for arc in &self.arrows {
            match (&arc.from, &arc.to) {
                (Node::Place(p), Node::Transition(t)) if t == transition => {
                    if !state.contains(p) {
                        return (false, places_to_remove, places_to_add);
                    } else {
                        places_to_remove.push(p.clone());
                    }
                }
                (Node::Transition(t), Node::Place(p)) if t == transition => {
                    if state.contains(p) {
                        return (false, places_to_remove, places_to_add);
                    } else {
                        places_to_add.push(p.clone());
                    }
                }
                _ => continue,
            }
        }

        (true, places_to_remove, places_to_add)
    }

    fn execute_transition(&mut self, transition: Action) -> bool {
        let (can_execute, places_to_remove, places_to_add) =
            self.prepare_transition(&self.state, &transition);

        if !can_execute {
            return false;
        }

        for place in places_to_remove {
            if places_to_add.contains(&place) {
                panic!(
                    "Place {:?} cannot be removed and added at the same time",
                    place
                );
            }
            self.state.remove(&place);
        }
        self.state.extend(places_to_add);
        true
    }
}

fn main() {
    let mut cm = CoffeeMachine::new();
    cm.execute_process();
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_prepare_transition_grind_beans() {
        let cm = CoffeeMachine::new();
        let state: HashSet<State> = [State::CoffeeBeans].iter().cloned().collect();
        let transition = Action::GrindBeans;
        let (can_execute, places_to_remove, _) = cm.prepare_transition(&state, &transition);
        assert!(can_execute, "GrindBeans should be able to execute");
        assert!(
            places_to_remove.contains(&State::CoffeeBeans),
            "CoffeeBeans should be in the places to remove"
        );
    }
    #[test]
    fn test_petri_net_process() {
        let mut cm = CoffeeMachine::new();
        cm.execute_process();
        println!("{:?}", cm.state);
    }
}
