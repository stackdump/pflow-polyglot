# Coffee Machine State Machine

This project demonstrates the implementation of a coffee vending machine using state machines
in different programming languages.

[![pflow](https://pflow.dev/img/zb2rhjeJ8bKSGRDHYv1e4Ap6wZrXvF6hqQkGYW7B1hk1KBsWa.svg)](https://pflow.dev/p/zb2rhjeJ8bKSGRDHYv1e4Ap6wZrXvF6hqQkGYW7B1hk1KBsWa/)

Click the image above to view the state machine in the [PFlow](https://pflow.dev) editor.

## Contributing

Contributions are welcome! Feel free to add new implementations in different languages or improve existing ones.

## State Machine Implementation

The state machine is implemented using the following components:
- **States**: Represent the different states of the coffee machine (e.g., `BoiledWater`, `GroundCoffee`, `CoffeeInPot`).
- **Transitions**: Represent the actions that cause state changes (e.g., `BrewCoffee`, `PourCoffee`).
- **Arrows**: Define the allowed transitions between states.
- **Guards**: Ensure that certain transitions only occur when specific conditions are met.

## Languages

The state machine is implemented in multiple programming languages to compare their behavior and ensure consistency.
Each implementation follows the same Petri net model.

### Other Languages

Implementations in other languages (e.g., Python, Java, C++) will be added in their respective directories.
Each implementation will follow the same structure and logic as the Rust implementation.

## Running the State Machine

To run all samples just use
```
make all
```

To run a specific language use
```
make run-bash
```
