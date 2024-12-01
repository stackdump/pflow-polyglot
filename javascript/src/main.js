const CoffeeMachine = require('./index.js');
const cm = new CoffeeMachine();
cm.executeProcess();

/*
> pflow-js@0.1.0 run
> node ./src/main.js

Step #1: BoilWater => Set(5) { 'CoffeeBeans', 'Filter', 'Cup', 'Pending', 'BoiledWater' }
Step #2: GrindBeans => Set(5) { 'Filter', 'Cup', 'Pending', 'BoiledWater', 'GroundCoffee' }
Step #3: BrewCoffee => Set(3) { 'Cup', 'Pending', 'CoffeeInPot' }
Step #4: Send => Set(3) { 'Cup', 'CoffeeInPot', 'Sent' }
Step #5: Credit => Set(3) { 'Cup', 'CoffeeInPot', 'Payment' }
Step #6: PourCoffee => Set(1) { 'Payment' }
*/