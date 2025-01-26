// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract CoffeeWorkflow {
    // States and their respective boolean values
    mapping(string => bool) private states;

    // Events for each transition
    event BoilWaterEvent();
    event GrindBeansEvent();
    event BrewCoffeeEvent();
    event PourCoffeeEvent();
    event SendEvent();
    event CreditEvent();

    constructor() {
        // Initialize states
        states["Water"] = true;
        states["BoiledWater"] = false;
        states["CoffeeBeans"] = true;
        states["GroundCoffee"] = false;
        states["Filter"] = true;
        states["CoffeeInPot"] = false;
        states["Pending"] = true;
        states["Sent"] = false;
        states["Payment"] = false;
        states["Cup"] = true;
    }

    // Helper to check state
    modifier stateIsTrue(string memory state) {
        require(states[state], "State not active");
        _;
    }

    // Helper to set states
    function setState(string memory state, bool value) private {
        states[state] = value;
    }

    // Transition: Boil Water
    function boilWater() external stateIsTrue("Water") {
        setState("Water", false);
        setState("BoiledWater", true);
        emit BoilWaterEvent();
    }

    // Transition: Grind Beans
    function grindBeans() external stateIsTrue("CoffeeBeans") {
        setState("CoffeeBeans", false);
        setState("GroundCoffee", true);
        emit GrindBeansEvent();
    }

    // Transition: Brew Coffee
    function brewCoffee() external stateIsTrue("BoiledWater") stateIsTrue("GroundCoffee") stateIsTrue("Filter") {
        setState("BoiledWater", false);
        setState("GroundCoffee", false);
        setState("Filter", false);
        setState("CoffeeInPot", true);
        emit BrewCoffeeEvent();
    }

    // Transition: Pour Coffee
    function pourCoffee() external stateIsTrue("CoffeeInPot") stateIsTrue("Cup") {
        setState("CoffeeInPot", false);
        setState("Cup", false);
        emit PourCoffeeEvent();
    }

    // Transition: Send
    function send() external stateIsTrue("Pending") {
        setState("Pending", false);
        setState("Sent", true);
        emit SendEvent();
    }

    // Transition: Credit
    function credit() external stateIsTrue("Sent") {
        setState("Sent", false);
        setState("Payment", true);
        emit CreditEvent();
    }

    // View current states for debugging or inspection
    function viewStates() external view returns (string memory) {
        string memory result = "Current States: \n";

        if (states["Water"]) result = string(abi.encodePacked(result, "Water\n"));
        if (states["BoiledWater"]) result = string(abi.encodePacked(result, "BoiledWater\n"));
        if (states["CoffeeBeans"]) result = string(abi.encodePacked(result, "CoffeeBeans\n"));
        if (states["GroundCoffee"]) result = string(abi.encodePacked(result, "GroundCoffee\n"));
        if (states["Filter"]) result = string(abi.encodePacked(result, "Filter\n"));
        if (states["CoffeeInPot"]) result = string(abi.encodePacked(result, "CoffeeInPot\n"));
        if (states["Pending"]) result = string(abi.encodePacked(result, "Pending\n"));
        if (states["Sent"]) result = string(abi.encodePacked(result, "Sent\n"));
        if (states["Payment"]) result = string(abi.encodePacked(result, "Payment\n"));
        if (states["Cup"]) result = string(abi.encodePacked(result, "Cup\n"));

        return result;
    }
}
