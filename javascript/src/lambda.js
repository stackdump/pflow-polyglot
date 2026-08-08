// Lambda form: the net is a set of pure Marking -> [Marking, fired] functions
// composed in a fixed schedule. No arrows, no guards list, no enablement
// search — the arcs survive only as control flow inside each transition.
//
// The fixed schedule is not an independent authorial choice: it is the firing
// sequence the canonical scheduling policy yields, precomputed with the search
// removed.
//
// See FORMS.md; output must match parity/trace.golden.

const INITIAL_MARKING = ['Water', 'CoffeeBeans', 'Filter', 'Cup', 'Pending'];

// Canonical trace rendering: marked places, sorted, comma-joined.
function render(marking) {
    return [...marking].sort().join(',');
}

// Apply an arc pattern to a *copy* of the marking. The lambda form is pure: a
// transition that does not fire returns its input untouched.
function fire(marking, remove = [], add = []) {
    const next = new Set(marking);
    for (const place of remove) {
        next.delete(place);
    }
    for (const place of add) {
        next.add(place);
    }
    return next;
}

const has = (marking, ...places) => places.every((p) => marking.has(p));

function boilWater(marking) {
    if (!has(marking, 'Water') || has(marking, 'BoiledWater')) {
        return [marking, false];
    }
    return [fire(marking, ['Water'], ['BoiledWater']), true];
}

function grindBeans(marking) {
    if (!has(marking, 'CoffeeBeans') || has(marking, 'GroundCoffee')) {
        return [marking, false];
    }
    return [fire(marking, ['CoffeeBeans'], ['GroundCoffee']), true];
}

function brewCoffee(marking) {
    if (!has(marking, 'BoiledWater', 'GroundCoffee', 'Filter') || has(marking, 'CoffeeInPot')) {
        return [marking, false];
    }
    return [fire(marking, ['BoiledWater', 'GroundCoffee', 'Filter'], ['CoffeeInPot']), true];
}

function send(marking) {
    if (!has(marking, 'Pending') || has(marking, 'Sent')) {
        return [marking, false];
    }
    return [fire(marking, ['Pending'], ['Sent']), true];
}

function credit(marking) {
    if (!has(marking, 'Sent') || has(marking, 'Payment')) {
        return [marking, false];
    }
    return [fire(marking, ['Sent'], ['Payment']), true];
}

// Carries the model's one guard: Payment must be present, and is not consumed.
function pourCoffee(marking) {
    if (!has(marking, 'Payment')) {
        return [marking, false];
    }
    if (!has(marking, 'CoffeeInPot', 'Cup')) {
        return [marking, false];
    }
    return [fire(marking, ['CoffeeInPot', 'Cup']), true];
}

// The canonical firing order. Unlike the interpreter form, nothing here
// searches for it — it is the author's claim about the model.
const SCHEDULE = [
    ['BoilWater', boilWater],
    ['GrindBeans', grindBeans],
    ['BrewCoffee', brewCoffee],
    ['Send', send],
    ['Credit', credit],
    ['PourCoffee', pourCoffee],
];

function main() {
    let marking = new Set(INITIAL_MARKING);
    let step = 0;
    for (const [name, transition] of SCHEDULE) {
        const [next, fired] = transition(marking);
        if (!fired) {
            continue;
        }
        marking = next;
        step++;
        console.log(`Step #${step}: ${name} => ${render(marking)}`);
    }
}

if (require.main === module) {
    main();
}

module.exports = { INITIAL_MARKING, SCHEDULE, render, fire, main };
