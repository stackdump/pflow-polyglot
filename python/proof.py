# Proof form: the net is a claim about every reachable marking, checked by an
# exhaustive model-check before a single trace line is printed. See FORMS.md;
# output must match parity/trace.golden.
#
# The marking is a multiset — a count per place, not a set — and enablement is
# plain P/T semantics with no `capacity: 1` clause. Startup verifies:
#
#  1. 1-safety is structural: no reachable marking holds two tokens anywhere,
#     even without the capacity clause. This licenses the set representation
#     every other form uses.
#  2. The outcome is confluent: every reachable deadlock is exactly {Payment}.
#
# A violation aborts with the offending marking on stderr — which fails the
# parity gate, since a program that dies cannot print six lines.
import sys
from collections import deque

# Places in a fixed order, so a marking is a plain tuple of counts and its own
# dict key.
PLACES = (
    "Water", "BoiledWater", "CoffeeBeans", "GroundCoffee", "Filter",
    "CoffeeInPot", "Pending", "Sent", "Payment", "Cup",
)
INDEX = {p: i for i, p in enumerate(PLACES)}

# (name, inputs, outputs, guards): inputs consumed, outputs produced, guards
# read but not consumed.
TRANSITIONS = (
    ("BoilWater", ("Water",), ("BoiledWater",), ()),
    ("GrindBeans", ("CoffeeBeans",), ("GroundCoffee",), ()),
    ("BrewCoffee", ("BoiledWater", "GroundCoffee", "Filter"), ("CoffeeInPot",), ()),
    ("PourCoffee", ("CoffeeInPot", "Cup"), (), ("Payment",)),
    ("Send", ("Pending",), ("Sent",), ()),
    ("Credit", ("Sent",), ("Payment",), ()),
)

# The scheduler's candidate order: every transition, sorted by name. This is
# what implements the canonical scheduling policy (FORMS.md) — fire the enabled
# transition whose name is lexicographically least. The order the tuple is
# written in is therefore not load-bearing, but do not drop the sort on that
# basis: only 90 of the 720 possible orders produce parity/trace.golden.
SCHEDULE = tuple(sorted(TRANSITIONS, key=lambda t: t[0]))

INITIAL = tuple(
    1 if p in {"Water", "CoffeeBeans", "Filter", "Cup", "Pending"} else 0
    for p in PLACES
)


def enabled(marking, transition):
    """Plain P/T enablement: inputs and guards marked. Deliberately no
    "outputs clear" clause — that the clause is never needed is check 1."""
    _, inputs, _, guards = transition
    return all(marking[INDEX[p]] >= 1 for p in inputs) and all(
        marking[INDEX[p]] >= 1 for p in guards
    )


def fire(marking, transition):
    _, inputs, outputs, _ = transition
    counts = list(marking)
    for p in inputs:
        counts[INDEX[p]] -= 1
    for p in outputs:
        counts[INDEX[p]] += 1
    return tuple(counts)


def render(marking):
    """Canonical trace rendering: marked places, sorted, comma-joined."""
    return ",".join(sorted(p for p in PLACES if marking[INDEX[p]] > 0))


def verify():
    """Explores the full reachable state space by breadth-first search and
    checks both claims. An unsafe marking fails immediately, so the explored
    space is a subset of {0,1}^10 and the search needs no bound to
    terminate."""
    seen = {INITIAL}
    frontier = deque([INITIAL])
    deadlocks = []

    while frontier:
        marking = frontier.popleft()

        if any(count > 1 for count in marking):
            return f"1-safety violated: reachable marking {marking}"

        successors = [fire(marking, t) for t in TRANSITIONS if enabled(marking, t)]
        if not successors:
            deadlocks.append(marking)
        for nxt in successors:
            if nxt not in seen:
                seen.add(nxt)
                frontier.append(nxt)

    if len(deadlocks) != 1 or render(deadlocks[0]) != "Payment":
        got = " ".join("{%s}" % render(d) for d in deadlocks)
        return f"deadlock not unique {{Payment}}: got {got}"
    return None


def execute_process():
    """The interpreter form's scheduler, running on a net the model-check has
    already verified."""
    marking = INITIAL
    step = 0
    while True:
        for transition in SCHEDULE:
            if enabled(marking, transition):
                marking = fire(marking, transition)
                step += 1
                print(f"Step #{step}: {transition[0]} => {render(marking)}")
                break
        else:
            return


def main():
    error = verify()
    if error is not None:
        print(f"proof failed: {error}", file=sys.stderr)
        sys.exit(1)
    execute_process()


if __name__ == "__main__":
    main()
