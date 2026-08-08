//! Lambda form: the net is a set of pure `Marking -> (Marking, bool)` functions
//! composed in a fixed schedule. No arrows, no guards list, no enablement
//! search — the arcs survive only as control flow inside each transition.
//!
//! The fixed schedule is not an independent authorial choice: it is the firing
//! sequence the canonical scheduling policy yields, precomputed with the
//! search removed.
//!
//! See FORMS.md; output must match parity/trace.golden.

use std::collections::BTreeSet;

/// The set of marked places. The net is 1-safe, so membership is all that
/// matters. `BTreeSet` keeps it sorted for the canonical rendering.
type Marking = BTreeSet<&'static str>;

fn initial_marking() -> Marking {
    ["Water", "CoffeeBeans", "Filter", "Cup", "Pending"]
        .into_iter()
        .collect()
}

fn render(m: &Marking) -> String {
    m.iter().copied().collect::<Vec<_>>().join(",")
}

/// Applies an arc pattern to a *copy* of the marking. The lambda form is pure:
/// a transition that does not fire returns its input untouched.
fn fire(m: &Marking, remove: &[&'static str], add: &[&'static str]) -> Marking {
    let mut next = m.clone();
    for place in remove {
        next.remove(place);
    }
    for place in add {
        next.insert(place);
    }
    next
}

fn boil_water(m: &Marking) -> (Marking, bool) {
    if !m.contains("Water") || m.contains("BoiledWater") {
        return (m.clone(), false);
    }
    (fire(m, &["Water"], &["BoiledWater"]), true)
}

fn grind_beans(m: &Marking) -> (Marking, bool) {
    if !m.contains("CoffeeBeans") || m.contains("GroundCoffee") {
        return (m.clone(), false);
    }
    (fire(m, &["CoffeeBeans"], &["GroundCoffee"]), true)
}

fn brew_coffee(m: &Marking) -> (Marking, bool) {
    let has_inputs =
        m.contains("BoiledWater") && m.contains("GroundCoffee") && m.contains("Filter");
    if !has_inputs || m.contains("CoffeeInPot") {
        return (m.clone(), false);
    }
    (
        fire(
            m,
            &["BoiledWater", "GroundCoffee", "Filter"],
            &["CoffeeInPot"],
        ),
        true,
    )
}

fn send(m: &Marking) -> (Marking, bool) {
    if !m.contains("Pending") || m.contains("Sent") {
        return (m.clone(), false);
    }
    (fire(m, &["Pending"], &["Sent"]), true)
}

fn credit(m: &Marking) -> (Marking, bool) {
    if !m.contains("Sent") || m.contains("Payment") {
        return (m.clone(), false);
    }
    (fire(m, &["Sent"], &["Payment"]), true)
}

/// Carries the model's one guard: Payment must be present, and is not consumed.
fn pour_coffee(m: &Marking) -> (Marking, bool) {
    if !m.contains("Payment") {
        return (m.clone(), false);
    }
    if !m.contains("CoffeeInPot") || !m.contains("Cup") {
        return (m.clone(), false);
    }
    (fire(m, &["CoffeeInPot", "Cup"], &[]), true)
}

/// The canonical firing order. Unlike the interpreter form, nothing here
/// searches for it — it is the author's claim about the model.
const SCHEDULE: [(&str, fn(&Marking) -> (Marking, bool)); 6] = [
    ("BoilWater", boil_water),
    ("GrindBeans", grind_beans),
    ("BrewCoffee", brew_coffee),
    ("Send", send),
    ("Credit", credit),
    ("PourCoffee", pour_coffee),
];

fn main() {
    let mut marking = initial_marking();
    let mut step = 0;
    for (name, transition) in SCHEDULE {
        let (next, fired) = transition(&marking);
        if !fired {
            continue;
        }
        marking = next;
        step += 1;
        println!("Step #{}: {} => {}", step, name, render(&marking));
    }
}
