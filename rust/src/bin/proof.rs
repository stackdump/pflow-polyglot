//! Proof form: the net is a claim about every reachable marking, checked by an
//! exhaustive model-check before a single trace line is printed. See FORMS.md;
//! output must match parity/trace.golden.
//!
//! The marking is a multiset — a count per place, not a set — and enablement
//! is plain P/T semantics with no `capacity: 1` clause. Startup verifies:
//!
//!  1. 1-safety is structural: no reachable marking holds two tokens anywhere,
//!     even without the capacity clause. This licenses the set representation
//!     every other form uses.
//!  2. The outcome is confluent: every reachable deadlock is exactly {Payment}.
//!
//! A violation panics before the first trace line — which fails the parity
//! gate, since a program that dies cannot print six lines.

use std::collections::HashSet;

/// Places in a fixed order, so a marking is a plain array of counts and its
/// own hash identity.
const PLACES: [&str; 10] = [
    "Water",
    "BoiledWater",
    "CoffeeBeans",
    "GroundCoffee",
    "Filter",
    "CoffeeInPot",
    "Pending",
    "Sent",
    "Payment",
    "Cup",
];

/// A token count per place, indexed like PLACES.
type Marking = [u32; 10];

fn place_index(name: &str) -> usize {
    PLACES.iter().position(|p| *p == name).expect("unknown place")
}

/// Transition inputs are consumed, outputs produced, guards read but not
/// consumed.
struct Transition {
    name: &'static str,
    inputs: &'static [&'static str],
    outputs: &'static [&'static str],
    guards: &'static [&'static str],
}

/// The net. `schedule()` sorts these by name before the trace loop walks them,
/// so the order written here is not load-bearing — but do not drop the sort on
/// that basis: only 90 of the 720 possible orders produce parity/trace.golden.
const TRANSITIONS: [Transition; 6] = [
    Transition {
        name: "BoilWater",
        inputs: &["Water"],
        outputs: &["BoiledWater"],
        guards: &[],
    },
    Transition {
        name: "GrindBeans",
        inputs: &["CoffeeBeans"],
        outputs: &["GroundCoffee"],
        guards: &[],
    },
    Transition {
        name: "BrewCoffee",
        inputs: &["BoiledWater", "GroundCoffee", "Filter"],
        outputs: &["CoffeeInPot"],
        guards: &[],
    },
    Transition {
        name: "PourCoffee",
        inputs: &["CoffeeInPot", "Cup"],
        outputs: &[],
        guards: &["Payment"],
    },
    Transition {
        name: "Send",
        inputs: &["Pending"],
        outputs: &["Sent"],
        guards: &[],
    },
    Transition {
        name: "Credit",
        inputs: &["Sent"],
        outputs: &["Payment"],
        guards: &[],
    },
];

fn initial_marking() -> Marking {
    let mut m = [0; 10];
    for p in ["Water", "CoffeeBeans", "Filter", "Cup", "Pending"] {
        m[place_index(p)] = 1;
    }
    m
}

/// Plain P/T enablement: inputs and guards marked. Deliberately no
/// "outputs clear" clause — that the clause is never needed is check 1.
fn enabled(m: &Marking, t: &Transition) -> bool {
    t.inputs.iter().all(|p| m[place_index(p)] >= 1)
        && t.guards.iter().all(|p| m[place_index(p)] >= 1)
}

fn fire(m: &Marking, t: &Transition) -> Marking {
    let mut next = *m;
    for p in t.inputs {
        next[place_index(p)] -= 1;
    }
    for p in t.outputs {
        next[place_index(p)] += 1;
    }
    next
}

/// Canonical trace rendering: marked places, sorted, comma-joined.
fn render(m: &Marking) -> String {
    let mut marked: Vec<&str> = PLACES
        .iter()
        .enumerate()
        .filter(|(i, _)| m[*i] > 0)
        .map(|(_, p)| *p)
        .collect();
    marked.sort_unstable();
    marked.join(",")
}

/// Explores the full reachable state space by breadth-first search and checks
/// both claims. An unsafe marking fails immediately, so the explored space is
/// a subset of {0,1}^10 and the search needs no bound to terminate.
fn verify() -> Result<(), String> {
    let initial = initial_marking();
    let mut seen: HashSet<Marking> = HashSet::from([initial]);
    let mut frontier = vec![initial];
    let mut deadlocks = vec![];

    while let Some(m) = frontier.pop() {
        if m.iter().any(|c| *c > 1) {
            return Err(format!("1-safety violated: reachable marking {:?}", m));
        }

        let mut fired = false;
        for t in &TRANSITIONS {
            if !enabled(&m, t) {
                continue;
            }
            fired = true;
            let next = fire(&m, t);
            if seen.insert(next) {
                frontier.push(next);
            }
        }
        if !fired {
            deadlocks.push(m);
        }
    }

    if deadlocks.len() != 1 || render(&deadlocks[0]) != "Payment" {
        let got: Vec<String> = deadlocks.iter().map(|d| format!("{{{}}}", render(d))).collect();
        return Err(format!("deadlock not unique {{Payment}}: got {}", got.join(" ")));
    }
    Ok(())
}

/// The scheduler's candidate order: every transition, sorted by name. This is
/// what implements the canonical scheduling policy (FORMS.md) — fire the
/// enabled transition whose name is lexicographically least.
fn schedule() -> Vec<&'static Transition> {
    let mut all: Vec<&'static Transition> = TRANSITIONS.iter().collect();
    all.sort_by_key(|t| t.name);
    all
}

/// The interpreter form's scheduler, running on a net the model-check has
/// already verified.
fn execute_process() {
    let mut m = initial_marking();
    let mut step = 0;
    let candidates = schedule();
    loop {
        let Some(t) = candidates.iter().copied().find(|t| enabled(&m, t)) else {
            return;
        };
        m = fire(&m, t);
        step += 1;
        println!("Step #{}: {} => {}", step, t.name, render(&m));
    }
}

fn main() {
    if let Err(err) = verify() {
        eprintln!("proof failed: {}", err);
        std::process::exit(1);
    }
    execute_process();
}
