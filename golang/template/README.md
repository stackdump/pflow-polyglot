# go generated CoffeeMachine

This directory contains generator code that uses pflow json input
to template an equivalent state machine as golang code

### generate

run.sh generates the state machine output
```shell
go run generate.go model.json | gofmt > coffee_machine.go 
go run coffee_machine.go
```

output
```
1: BoilWater
2: GrindBeans
3: BrewCoffee
4: Send
5: Credit
6: PourCoffee
Final State: map[BoiledWater:false CoffeeBeans:false CoffeeInPot:false Cup:false Filter:false GroundC
```
