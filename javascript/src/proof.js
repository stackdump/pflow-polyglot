// Proof form: the net is a claim about every reachable marking, checked by an
// exhaustive model-check before a single trace line is printed. See FORMS.md;
// output must match parity/trace.golden.
//
// The marking is a multiset — a count per place, not a set — and enablement is
// plain P/T semantics with no `capacity: 1` clause. Startup verifies:
//
//  1. 1-safety is structural: no reachable marking holds two tokens anywhere,
//     even without the capacity clause. This licenses the set representation
//     every other form uses.
//  2. The outcome is confluent: every reachable deadlock is exactly {Payment}.
//
// A violation aborts with the offending marking on stderr — which fails the
// parity gate, since a program that dies cannot print six lines.

// Places in a fixed order, so a marking is a plain array of counts and its
// join is a Set key.
const PLACES = [
    'Water', 'BoiledWater', 'CoffeeBeans', 'GroundCoffee', 'Filter',
    'CoffeeInPot', 'Pending', 'Sent', 'Payment', 'Cup',
];
const INDEX = new Map(PLACES.map((p, i) => [p, i]));

// Inputs consumed, outputs produced, guards read but not consumed. Scheduler
// search order — the interpreter form's declaration order.
const TRANSITIONS = [
    { name: 'BoilWater', inputs: ['Water'], outputs: ['BoiledWater'], guards: [] },
    { name: 'GrindBeans', inputs: ['CoffeeBeans'], outputs: ['GroundCoffee'], guards: [] },
    { name: 'BrewCoffee', inputs: ['BoiledWater', 'GroundCoffee', 'Filter'], outputs: ['CoffeeInPot'], guards: [] },
    { name: 'PourCoffee', inputs: ['CoffeeInPot', 'Cup'], outputs: [], guards: ['Payment'] },
    { name: 'Send', inputs: ['Pending'], outputs: ['Sent'], guards: [] },
    { name: 'Credit', inputs: ['Sent'], outputs: ['Payment'], guards: [] },
];

function initialMarking() {
    const m = PLACES.map(() => 0);
    for (const p of ['Water', 'CoffeeBeans', 'Filter', 'Cup', 'Pending']) {
        m[INDEX.get(p)] = 1;
    }
    return m;
}

// Plain P/T enablement: inputs and guards marked. Deliberately no
// "outputs clear" clause — that the clause is never needed is check 1.
function enabled(marking, t) {
    return t.inputs.every((p) => marking[INDEX.get(p)] >= 1)
        && t.guards.every((p) => marking[INDEX.get(p)] >= 1);
}

function fire(marking, t) {
    const next = [...marking];
    for (const p of t.inputs) {
        next[INDEX.get(p)] -= 1;
    }
    for (const p of t.outputs) {
        next[INDEX.get(p)] += 1;
    }
    return next;
}

// Canonical trace rendering: marked places, sorted, comma-joined.
function render(marking) {
    return PLACES.filter((p) => marking[INDEX.get(p)] > 0).sort().join(',');
}

// Explores the full reachable state space by breadth-first search and checks
// both claims. An unsafe marking fails immediately, so the explored space is
// a subset of {0,1}^10 and the search needs no bound to terminate.
function verify() {
    const initial = initialMarking();
    const seen = new Set([initial.join(',')]);
    const frontier = [initial];
    const deadlocks = [];

    while (frontier.length > 0) {
        const marking = frontier.shift();

        if (marking.some((count) => count > 1)) {
            return `1-safety violated: reachable marking ${marking.join(',')}`;
        }

        const successors = TRANSITIONS
            .filter((t) => enabled(marking, t))
            .map((t) => fire(marking, t));
        if (successors.length === 0) {
            deadlocks.push(marking);
        }
        for (const next of successors) {
            const key = next.join(',');
            if (!seen.has(key)) {
                seen.add(key);
                frontier.push(next);
            }
        }
    }

    if (deadlocks.length !== 1 || render(deadlocks[0]) !== 'Payment') {
        const got = deadlocks.map((d) => `{${render(d)}}`).join(' ');
        return `deadlock not unique {Payment}: got ${got}`;
    }
    return null;
}

// The interpreter form's scheduler, running on a net the model-check has
// already verified.
function executeProcess() {
    let marking = initialMarking();
    let step = 0;
    for (;;) {
        const t = TRANSITIONS.find((t) => enabled(marking, t));
        if (!t) {
            return;
        }
        marking = fire(marking, t);
        step += 1;
        console.log(`Step #${step}: ${t.name} => ${render(marking)}`);
    }
}

function main() {
    const error = verify();
    if (error !== null) {
        console.error(`proof failed: ${error}`);
        process.exit(1);
    }
    executeProcess();
}

if (require.main === module) {
    main();
}

module.exports = { initialMarking, verify, render, main };
