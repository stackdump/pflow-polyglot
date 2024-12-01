const assert = require('assert');
const CoffeeMachine = require('../src/index.js');

describe('CoffeeMachine', function() {
    it('should execute the coffee making process correctly', function() {
        const cm = new CoffeeMachine();
        cm.executeProcess();

        // Check final state
        const expectedFinalState = new Set([
            cm.State.Payment
        ]);

        assert.deepStrictEqual(cm.state, expectedFinalState);
    });

    it('should not enable PourCoffee in the state [Cup, Pending, CoffeeInPot]', function() {
        const cm = new CoffeeMachine();
        cm.state = new Set([
            cm.State.Cup,
            cm.State.Pending,
            cm.State.CoffeeInPot
        ]);

        const canExecute = cm.prepareTransition(cm.state, cm.Action.PourCoffee)[0];
        assert.strictEqual(canExecute, false, 'Expected PourCoffee not to be enabled in the state [Cup, Pending, CoffeeInPot]');
    });
});