// Contract form: the net is a public API surface. There is no scheduler and no
// schedule — each transition is an entry point that either fires and records an
// event, or throws NotEnabled. The caller decides the order.
//
// This mirrors solidity/contract.sol, where enablement is enforced by `require`
// in a modifier and the event log is the trace.
//
// The driver calls the transitions in the order the canonical scheduling
// policy yields; the methods themselves accept any order and refuse what is
// not enabled.
//
// See FORMS.md; output must match parity/trace.golden.

// Thrown when a transition is called in a marking that does not enable it. The
// contract never partially applies: enablement is checked in full before
// anything is mutated.
class NotEnabled extends Error {
    constructor(message) {
        super(message);
        this.name = 'NotEnabled';
    }
}

// Holds the marking and the log of fired transitions. Callers cannot reach the
// marking directly; the only way to change it is a transition.
class CoffeeMachine {
    #marked = new Set(['Water', 'CoffeeBeans', 'Filter', 'Cup', 'Pending']);

    #events = [];

    // The enablement check every entry point runs first: all inputs marked, all
    // outputs clear, all guards satisfied.
    #require(name, { inputs = [], outputs = [], guards = [] }) {
        for (const place of inputs) {
            if (!this.#marked.has(place)) {
                throw new NotEnabled(`${name}: missing input ${place}`);
            }
        }
        for (const place of outputs) {
            if (this.#marked.has(place)) {
                throw new NotEnabled(`${name}: output ${place} already marked`);
            }
        }
        for (const place of guards) {
            if (!this.#marked.has(place)) {
                throw new NotEnabled(`${name}: guard ${place} unsatisfied`);
            }
        }
    }

    #fire(name, arcs) {
        this.#require(name, arcs);
        for (const place of arcs.inputs ?? []) {
            this.#marked.delete(place);
        }
        for (const place of arcs.outputs ?? []) {
            this.#marked.add(place);
        }
        this.#events.push(name);
    }

    boilWater() {
        this.#fire('BoilWater', { inputs: ['Water'], outputs: ['BoiledWater'] });
    }

    grindBeans() {
        this.#fire('GrindBeans', { inputs: ['CoffeeBeans'], outputs: ['GroundCoffee'] });
    }

    brewCoffee() {
        this.#fire('BrewCoffee', {
            inputs: ['BoiledWater', 'GroundCoffee', 'Filter'],
            outputs: ['CoffeeInPot'],
        });
    }

    send() {
        this.#fire('Send', { inputs: ['Pending'], outputs: ['Sent'] });
    }

    credit() {
        this.#fire('Credit', { inputs: ['Sent'], outputs: ['Payment'] });
    }

    // Guarded on Payment, which it checks but does not consume.
    pourCoffee() {
        this.#fire('PourCoffee', { inputs: ['CoffeeInPot', 'Cup'], guards: ['Payment'] });
    }

    // The contract's view function: the marked places, sorted.
    get marking() {
        return [...this.#marked].sort().join(',');
    }

    // The log of transitions that have fired, in order.
    get events() {
        return [...this.#events];
    }
}

function main() {
    const cm = new CoffeeMachine();

    // The driver is the caller, not the machine. Calling these in any other
    // order throws NotEnabled rather than corrupting the marking.
    const calls = [
        ['BoilWater', () => cm.boilWater()],
        ['GrindBeans', () => cm.grindBeans()],
        ['BrewCoffee', () => cm.brewCoffee()],
        ['Send', () => cm.send()],
        ['Credit', () => cm.credit()],
        ['PourCoffee', () => cm.pourCoffee()],
    ];

    let step = 0;
    for (const [name, call] of calls) {
        try {
            call();
        } catch (err) {
            if (err instanceof NotEnabled) {
                continue;
            }
            throw err;
        }
        step++;
        console.log(`Step #${step}: ${name} => ${cm.marking}`);
    }
}

if (require.main === module) {
    main();
}

module.exports = { CoffeeMachine, NotEnabled, main };
