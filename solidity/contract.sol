// SPDX-License-Identifier: MIT
//
// Contract form, hand-written. This is the form Solidity forces on you: there
// is no scheduler and no stdout, so each transition is an external entry point
// guarded by `require`, and the event log is the trace.
//
// Every other language in this repo implements the same shape by hand
// (golang/contract, rust/src/bin/contract.rs, python/contract.py,
// javascript/src/contract.js, ruby/contract.rb, julia/contract.jl,
// haskell/contract.hs, bash/contract.sh) so the comparison is visible.
//
// The generated equivalent is solidity/generated.sol; diffing the two shows
// what tools/codegen does and does not capture.
//
// See FORMS.md.
pragma solidity ^0.8.18;

contract CoffeeMachine {
    // The marking is the set of marked places. The net is 1-safe: a place holds
    // zero or one token, which is why `bool` rather than a count.
    mapping(string => bool) private marked;

    // The trace. `state` is the canonical rendering used by every other
    // implementation: marked places, sorted, comma-joined.
    event Fired(string transition, string state);

    // Every place, in lexicographic order — the sort the canonical rendering
    // needs, resolved once at construction rather than on every call.
    string[10] private places = [
        "BoiledWater",
        "CoffeeBeans",
        "CoffeeInPot",
        "Cup",
        "Filter",
        "GroundCoffee",
        "Payment",
        "Pending",
        "Sent",
        "Water"
    ];

    constructor() {
        marked["Water"] = true;
        marked["CoffeeBeans"] = true;
        marked["Filter"] = true;
        marked["Cup"] = true;
        marked["Pending"] = true;
    }

    /// @dev An input place: must be marked, and is consumed.
    modifier consumes(string memory place) {
        require(marked[place], "not enabled: missing input");
        _;
    }

    /// @dev An output place: must be clear, because the net is 1-safe.
    modifier produces(string memory place) {
        require(!marked[place], "not enabled: output already marked");
        _;
    }

    /// @dev A guard: must be marked, and is *not* consumed.
    modifier requires(string memory place) {
        require(marked[place], "not enabled: guard unsatisfied");
        _;
    }

    /// @notice Whether a place currently holds a token.
    function isMarked(string calldata place) external view returns (bool) {
        return marked[place];
    }

    /// @notice Canonical trace rendering: marked places, sorted, comma-joined.
    function render() public view returns (string memory) {
        bytes memory out;
        bool first = true;
        for (uint256 i = 0; i < places.length; i++) {
            if (!marked[places[i]]) {
                continue;
            }
            if (!first) {
                out = abi.encodePacked(out, ",");
            }
            out = abi.encodePacked(out, places[i]);
            first = false;
        }
        return string(out);
    }

    function boilWater() external consumes("Water") produces("BoiledWater") {
        marked["Water"] = false;
        marked["BoiledWater"] = true;
        emit Fired("BoilWater", render());
    }

    function grindBeans() external consumes("CoffeeBeans") produces("GroundCoffee") {
        marked["CoffeeBeans"] = false;
        marked["GroundCoffee"] = true;
        emit Fired("GrindBeans", render());
    }

    function brewCoffee()
        external
        consumes("BoiledWater")
        consumes("GroundCoffee")
        consumes("Filter")
        produces("CoffeeInPot")
    {
        marked["BoiledWater"] = false;
        marked["GroundCoffee"] = false;
        marked["Filter"] = false;
        marked["CoffeeInPot"] = true;
        emit Fired("BrewCoffee", render());
    }

    function send() external consumes("Pending") produces("Sent") {
        marked["Pending"] = false;
        marked["Sent"] = true;
        emit Fired("Send", render());
    }

    function credit() external consumes("Sent") produces("Payment") {
        marked["Sent"] = false;
        marked["Payment"] = true;
        emit Fired("Credit", render());
    }

    /// @notice Guarded on Payment, which it checks but does not consume. This
    /// is the one guard in the model, and the reason the caller cannot pour
    /// before paying.
    function pourCoffee() external requires("Payment") consumes("CoffeeInPot") consumes("Cup") {
        marked["CoffeeInPot"] = false;
        marked["Cup"] = false;
        emit Fired("PourCoffee", render());
    }
}
