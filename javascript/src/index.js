class CoffeeMachine {
    constructor() {
        this.State = {
            Water: 'Water',
            BoiledWater: 'BoiledWater',
            CoffeeBeans: 'CoffeeBeans',
            GroundCoffee: 'GroundCoffee',
            Filter: 'Filter',
            CoffeeInPot: 'CoffeeInPot',
            Pending: 'Pending',
            Sent: 'Sent',
            Payment: 'Payment',
            Cup: 'Cup'
        };

        this.Action = {
            BoilWater: 'BoilWater',
            GrindBeans: 'GrindBeans',
            BrewCoffee: 'BrewCoffee',
            PourCoffee: 'PourCoffee',
            Send: 'Send',
            Credit: 'Credit'
        };

        this.state = new Set([
            this.State.Water,
            this.State.CoffeeBeans,
            this.State.Filter,
            this.State.Cup,
            this.State.Pending
        ]);

        this.arrows = [
            { from: { place: this.State.Water }, to: { transition: this.Action.BoilWater } },
            { from: { transition: this.Action.BoilWater }, to: { place: this.State.BoiledWater } },
            { from: { place: this.State.CoffeeBeans }, to: { transition: this.Action.GrindBeans } },
            { from: { transition: this.Action.GrindBeans }, to: { place: this.State.GroundCoffee } },
            { from: { place: this.State.BoiledWater }, to: { transition: this.Action.BrewCoffee } },
            { from: { place: this.State.GroundCoffee }, to: { transition: this.Action.BrewCoffee } },
            { from: { place: this.State.Filter }, to: { transition: this.Action.BrewCoffee } },
            { from: { transition: this.Action.BrewCoffee }, to: { place: this.State.CoffeeInPot } },
            { from: { place: this.State.CoffeeInPot }, to: { transition: this.Action.PourCoffee } },
            { from: { place: this.State.Cup }, to: { transition: this.Action.PourCoffee } },
            { from: { place: this.State.Pending }, to: { transition: this.Action.Send } },
            { from: { transition: this.Action.Send }, to: { place: this.State.Sent } },
            { from: { place: this.State.Sent }, to: { transition: this.Action.Credit } },
            { from: { transition: this.Action.Credit }, to: { place: this.State.Payment } }
        ];

        this.guards = [
            { from: { transition: this.Action.PourCoffee }, to: { place: this.State.Payment } }
        ];
    }

    guardFails(state, transition) {
        for (const guard of this.guards) {
            if (guard.from.transition === transition && !state.has(guard.to.place)) {
                return true;
            }
            if (guard.to.transition === transition && state.has(guard.from.place)) {
                return true;
            }
        }
        return false;
    }

    prepareTransition(state, transition) {
        const placesToRemove = [];
        const placesToAdd = [];

        if (this.guardFails(state, transition)) {
            return [false, placesToRemove, placesToAdd];
        }

        for (const arrow of this.arrows) {
            if (arrow.from.place && arrow.to.transition === transition) {
                if (!state.has(arrow.from.place)) {
                    return [false, placesToRemove, placesToAdd];
                }
                placesToRemove.push(arrow.from.place);
            }
            if (arrow.from.transition === transition && arrow.to.place) {
                if (state.has(arrow.to.place)) {
                    return [false, placesToRemove, placesToAdd];
                }
                placesToAdd.push(arrow.to.place);
            }
        }

        return [true, placesToRemove, placesToAdd];
    }

    executeTransition(transition) {
        const [canExecute, placesToRemove, placesToAdd] = this.prepareTransition(this.state, transition);

        if (!canExecute) {
            return false;
        }

        for (const place of placesToRemove) {
            this.state.delete(place);
        }
        for (const place of placesToAdd) {
            this.state.add(place);
        }
        return true;
    }

    executeProcess() {
        let step = 0;
        while (true) {
            let anyExecuted = false;
            for (const transition of Object.values(this.Action)) {
                if (this.executeTransition(transition)) {
                    anyExecuted = true;
                    step++;
                    console.log(`Step #${step}: ${transition} =>`, this.state);
                    break;
                }
            }
            if (!anyExecuted) {
                break;
            }
        }
    }
}

module.exports = CoffeeMachine;
