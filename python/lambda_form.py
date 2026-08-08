"""Lambda form: the net is a set of pure marking -> (marking, fired) functions
composed in a fixed schedule.

No arrows, no guards list, no enablement search — the arcs survive only as
control flow inside each transition. Named lambda_form rather than lambda
because `lambda` is a keyword.

The fixed schedule is not an independent authorial choice: it is the firing
sequence the canonical scheduling policy yields, precomputed with the search
removed.

See FORMS.md; output must match parity/trace.golden.
"""

INITIAL_MARKING = frozenset({"Water", "CoffeeBeans", "Filter", "Cup", "Pending"})


def render(marking):
    """Canonical trace rendering: marked places, sorted, comma-joined."""
    return ",".join(sorted(marking))


def fire(marking, remove=(), add=()):
    """Apply an arc pattern to a *copy* of the marking.

    The lambda form is pure: a transition that does not fire returns its input
    untouched.
    """
    return (marking - set(remove)) | set(add)


def boil_water(marking):
    if "Water" not in marking or "BoiledWater" in marking:
        return marking, False
    return fire(marking, remove=["Water"], add=["BoiledWater"]), True


def grind_beans(marking):
    if "CoffeeBeans" not in marking or "GroundCoffee" in marking:
        return marking, False
    return fire(marking, remove=["CoffeeBeans"], add=["GroundCoffee"]), True


def brew_coffee(marking):
    if not {"BoiledWater", "GroundCoffee", "Filter"} <= marking:
        return marking, False
    if "CoffeeInPot" in marking:
        return marking, False
    return fire(marking, remove=["BoiledWater", "GroundCoffee", "Filter"], add=["CoffeeInPot"]), True


def send(marking):
    if "Pending" not in marking or "Sent" in marking:
        return marking, False
    return fire(marking, remove=["Pending"], add=["Sent"]), True


def credit(marking):
    if "Sent" not in marking or "Payment" in marking:
        return marking, False
    return fire(marking, remove=["Sent"], add=["Payment"]), True


def pour_coffee(marking):
    """Carries the model's one guard: Payment must be present, and is not consumed."""
    if "Payment" not in marking:
        return marking, False
    if not {"CoffeeInPot", "Cup"} <= marking:
        return marking, False
    return fire(marking, remove=["CoffeeInPot", "Cup"]), True


# The canonical firing order. Unlike the interpreter form, nothing here searches
# for it — it is the author's claim about the model.
SCHEDULE = [
    ("BoilWater", boil_water),
    ("GrindBeans", grind_beans),
    ("BrewCoffee", brew_coffee),
    ("Send", send),
    ("Credit", credit),
    ("PourCoffee", pour_coffee),
]


def main():
    marking = INITIAL_MARKING
    step = 0
    for name, transition in SCHEDULE:
        marking, fired = transition(marking)
        if not fired:
            continue
        step += 1
        print(f"Step #{step}: {name} => {render(marking)}")


if __name__ == "__main__":
    main()
