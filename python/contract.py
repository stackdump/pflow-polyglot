"""Contract form: the net is a public API surface.

There is no scheduler and no schedule — each transition is an entry point that
either fires and records an event, or raises NotEnabled. The caller decides the
order.

This mirrors solidity/contract.sol, where enablement is enforced by `require` in
a modifier and the event log is the trace.

See FORMS.md; output must match parity/trace.golden.
"""


class NotEnabled(Exception):
    """Raised when a transition is called in a marking that does not enable it.

    The contract never partially applies: enablement is checked in full before
    anything is mutated.
    """


class CoffeeMachine:
    """Holds the marking and the log of fired transitions.

    Callers cannot reach the marking directly; the only way to change it is a
    transition.
    """

    def __init__(self):
        self._marked = {"Water", "CoffeeBeans", "Filter", "Cup", "Pending"}
        self._events = []

    def _require(self, name, inputs=(), outputs=(), guards=()):
        """The enablement check every entry point runs first."""
        for place in inputs:
            if place not in self._marked:
                raise NotEnabled(f"{name}: missing input {place}")
        for place in outputs:
            if place in self._marked:
                raise NotEnabled(f"{name}: output {place} already marked")
        for place in guards:
            if place not in self._marked:
                raise NotEnabled(f"{name}: guard {place} unsatisfied")

    def _fire(self, name, inputs=(), outputs=(), guards=()):
        self._require(name, inputs, outputs, guards)
        self._marked.difference_update(inputs)
        self._marked.update(outputs)
        self._events.append(name)

    def boil_water(self):
        self._fire("BoilWater", inputs=["Water"], outputs=["BoiledWater"])

    def grind_beans(self):
        self._fire("GrindBeans", inputs=["CoffeeBeans"], outputs=["GroundCoffee"])

    def brew_coffee(self):
        self._fire(
            "BrewCoffee",
            inputs=["BoiledWater", "GroundCoffee", "Filter"],
            outputs=["CoffeeInPot"],
        )

    def send(self):
        self._fire("Send", inputs=["Pending"], outputs=["Sent"])

    def credit(self):
        self._fire("Credit", inputs=["Sent"], outputs=["Payment"])

    def pour_coffee(self):
        """Guarded on Payment, which it checks but does not consume."""
        self._fire("PourCoffee", inputs=["CoffeeInPot", "Cup"], guards=["Payment"])

    @property
    def marking(self):
        """The contract's view function: the marked places, sorted."""
        return ",".join(sorted(self._marked))

    @property
    def events(self):
        """The log of transitions that have fired, in order."""
        return list(self._events)


def main():
    cm = CoffeeMachine()

    # The driver is the caller, not the machine. Calling these in any other
    # order raises NotEnabled rather than corrupting the marking.
    calls = [
        ("BoilWater", cm.boil_water),
        ("GrindBeans", cm.grind_beans),
        ("BrewCoffee", cm.brew_coffee),
        ("Send", cm.send),
        ("Credit", cm.credit),
        ("PourCoffee", cm.pour_coffee),
    ]

    step = 0
    for name, call in calls:
        try:
            call()
        except NotEnabled:
            continue
        step += 1
        print(f"Step #{step}: {name} => {cm.marking}")


if __name__ == "__main__":
    main()
