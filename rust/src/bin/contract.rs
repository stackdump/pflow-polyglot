//! Contract form: the net is a public API surface. There is no scheduler and no
//! schedule — each transition is an entry point that either fires and records an
//! event, or returns `NotEnabled`. The caller decides the order.
//!
//! This mirrors solidity/contract.sol, where enablement is enforced by `require`
//! in a modifier and the event log is the trace.
//!
//! See FORMS.md; output must match parity/trace.golden.

use std::collections::BTreeSet;
use std::fmt;

/// Returned when a transition is called in a marking that does not enable it.
/// The contract never panics and never partially applies.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum NotEnabled {
    MissingInput(&'static str),
    OutputAlreadyMarked(&'static str),
    GuardUnsatisfied(&'static str),
}

impl fmt::Display for NotEnabled {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            NotEnabled::MissingInput(p) => write!(f, "missing input {}", p),
            NotEnabled::OutputAlreadyMarked(p) => write!(f, "output {} already marked", p),
            NotEnabled::GuardUnsatisfied(p) => write!(f, "guard {} unsatisfied", p),
        }
    }
}

/// Holds the marking and the log of fired transitions. Callers cannot reach the
/// marking directly; the only way to change it is a transition.
pub struct CoffeeMachine {
    marked: BTreeSet<&'static str>,
    events: Vec<&'static str>,
}

impl CoffeeMachine {
    pub fn new() -> Self {
        CoffeeMachine {
            marked: ["Water", "CoffeeBeans", "Filter", "Cup", "Pending"]
                .into_iter()
                .collect(),
            events: Vec::new(),
        }
    }

    /// The enablement check every entry point runs first: all inputs marked,
    /// all outputs clear, all guards satisfied.
    fn require(
        &self,
        inputs: &[&'static str],
        outputs: &[&'static str],
        guards: &[&'static str],
    ) -> Result<(), NotEnabled> {
        for p in inputs {
            if !self.marked.contains(p) {
                return Err(NotEnabled::MissingInput(p));
            }
        }
        for p in outputs {
            if self.marked.contains(p) {
                return Err(NotEnabled::OutputAlreadyMarked(p));
            }
        }
        for p in guards {
            if !self.marked.contains(p) {
                return Err(NotEnabled::GuardUnsatisfied(p));
            }
        }
        Ok(())
    }

    fn fire(
        &mut self,
        name: &'static str,
        inputs: &[&'static str],
        outputs: &[&'static str],
        guards: &[&'static str],
    ) -> Result<(), NotEnabled> {
        self.require(inputs, outputs, guards)?;
        for p in inputs {
            self.marked.remove(p);
        }
        for p in outputs {
            self.marked.insert(p);
        }
        self.events.push(name);
        Ok(())
    }

    pub fn boil_water(&mut self) -> Result<(), NotEnabled> {
        self.fire("BoilWater", &["Water"], &["BoiledWater"], &[])
    }

    pub fn grind_beans(&mut self) -> Result<(), NotEnabled> {
        self.fire("GrindBeans", &["CoffeeBeans"], &["GroundCoffee"], &[])
    }

    pub fn brew_coffee(&mut self) -> Result<(), NotEnabled> {
        self.fire(
            "BrewCoffee",
            &["BoiledWater", "GroundCoffee", "Filter"],
            &["CoffeeInPot"],
            &[],
        )
    }

    pub fn send(&mut self) -> Result<(), NotEnabled> {
        self.fire("Send", &["Pending"], &["Sent"], &[])
    }

    pub fn credit(&mut self) -> Result<(), NotEnabled> {
        self.fire("Credit", &["Sent"], &["Payment"], &[])
    }

    /// Guarded on Payment, which it checks but does not consume.
    pub fn pour_coffee(&mut self) -> Result<(), NotEnabled> {
        self.fire("PourCoffee", &["CoffeeInPot", "Cup"], &[], &["Payment"])
    }

    /// The contract's view function: the marked places, sorted.
    pub fn marking(&self) -> String {
        self.marked.iter().copied().collect::<Vec<_>>().join(",")
    }

    /// The log of transitions that have fired, in order.
    pub fn events(&self) -> &[&'static str] {
        &self.events
    }
}

impl Default for CoffeeMachine {
    fn default() -> Self {
        Self::new()
    }
}

fn main() {
    let mut cm = CoffeeMachine::new();

    // The driver is the caller, not the machine. Calling these in any other
    // order returns NotEnabled rather than corrupting the marking.
    let calls: [(&str, fn(&mut CoffeeMachine) -> Result<(), NotEnabled>); 6] = [
        ("BoilWater", CoffeeMachine::boil_water),
        ("GrindBeans", CoffeeMachine::grind_beans),
        ("BrewCoffee", CoffeeMachine::brew_coffee),
        ("Send", CoffeeMachine::send),
        ("Credit", CoffeeMachine::credit),
        ("PourCoffee", CoffeeMachine::pour_coffee),
    ];

    let mut step = 0;
    for (name, call) in calls {
        if call(&mut cm).is_err() {
            continue;
        }
        step += 1;
        println!("Step #{}: {} => {}", step, name, cm.marking());
    }
}
