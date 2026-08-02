# Contract form: the net is a public API surface. There is no scheduler and no
# schedule — each transition is an entry point that either fires and records an
# event, or throws NotEnabled. The caller decides the order.
#
# This mirrors solidity/contract.sol, where enablement is enforced by `require`
# in a modifier and the event log is the trace.
#
# See FORMS.md; output must match parity/trace.golden.

# Thrown when a transition is called in a marking that does not enable it. The
# contract never partially applies: enablement is checked in full before
# anything is mutated.
struct NotEnabled <: Exception
    message::String
end

# Holds the marking and the log of fired transitions.
mutable struct CoffeeMachine
    marked::Set{String}
    events::Vector{String}
end

CoffeeMachine() = CoffeeMachine(
    Set(["Water", "CoffeeBeans", "Filter", "Cup", "Pending"]),
    String[],
)

# The enablement check every entry point runs first: all inputs marked, all
# outputs clear, all guards satisfied.
function require_enabled(cm::CoffeeMachine, name, inputs, outputs, guards)
    for place in inputs
        place in cm.marked || throw(NotEnabled("$name: missing input $place"))
    end
    for place in outputs
        place in cm.marked && throw(NotEnabled("$name: output $place already marked"))
    end
    for place in guards
        place in cm.marked || throw(NotEnabled("$name: guard $place unsatisfied"))
    end
end

function fire!(cm::CoffeeMachine, name; inputs=String[], outputs=String[], guards=String[])
    require_enabled(cm, name, inputs, outputs, guards)
    setdiff!(cm.marked, inputs)
    union!(cm.marked, outputs)
    push!(cm.events, name)
    return nothing
end

boil_water!(cm) = fire!(cm, "BoilWater", inputs=["Water"], outputs=["BoiledWater"])
grind_beans!(cm) = fire!(cm, "GrindBeans", inputs=["CoffeeBeans"], outputs=["GroundCoffee"])
brew_coffee!(cm) = fire!(cm, "BrewCoffee",
    inputs=["BoiledWater", "GroundCoffee", "Filter"], outputs=["CoffeeInPot"])
send!(cm) = fire!(cm, "Send", inputs=["Pending"], outputs=["Sent"])
credit!(cm) = fire!(cm, "Credit", inputs=["Sent"], outputs=["Payment"])
# Guarded on Payment, which it checks but does not consume.
pour_coffee!(cm) = fire!(cm, "PourCoffee", inputs=["CoffeeInPot", "Cup"], guards=["Payment"])

# The contract's view function: the marked places, sorted.
marking(cm::CoffeeMachine) = join(sort(collect(cm.marked)), ",")

function main()
    cm = CoffeeMachine()

    # The driver is the caller, not the machine. Calling these in any other
    # order throws NotEnabled rather than corrupting the marking.
    calls = [
        ("BoilWater", boil_water!),
        ("GrindBeans", grind_beans!),
        ("BrewCoffee", brew_coffee!),
        ("Send", send!),
        ("Credit", credit!),
        ("PourCoffee", pour_coffee!),
    ]

    step = 0
    for (name, call) in calls
        try
            call(cm)
        catch err
            err isa NotEnabled || rethrow()
            continue
        end
        step += 1
        println("Step #$step: $name => $(marking(cm))")
    end
end

main()
