# Lambda form: the net is a set of pure marking -> (marking, fired) functions
# composed in a fixed schedule. No arrows, no guards list, no enablement
# search — the arcs survive only as control flow inside each function.
#
# The fixed schedule is not an independent authorial choice: it is the firing
# sequence the canonical scheduling policy yields, precomputed with the search
# removed.
#
# See FORMS.md; output must match parity/trace.golden.

const Marking = Set{String}

initial_marking() = Marking(["Water", "CoffeeBeans", "Filter", "Cup", "Pending"])

# Canonical trace rendering: marked places, sorted, comma-joined.
render(m::Marking) = join(sort(collect(m)), ",")

# Apply an arc pattern to a *copy* of the marking. The lambda form is pure: a
# transition that does not fire returns its input untouched.
function fire(m::Marking; remove=String[], add=String[])
    next = copy(m)
    setdiff!(next, remove)
    union!(next, add)
    return next
end

function boil_water(m::Marking)
    ("Water" in m) || return (m, false)
    ("BoiledWater" in m) && return (m, false)
    return (fire(m, remove=["Water"], add=["BoiledWater"]), true)
end

function grind_beans(m::Marking)
    ("CoffeeBeans" in m) || return (m, false)
    ("GroundCoffee" in m) && return (m, false)
    return (fire(m, remove=["CoffeeBeans"], add=["GroundCoffee"]), true)
end

function brew_coffee(m::Marking)
    issubset(["BoiledWater", "GroundCoffee", "Filter"], m) || return (m, false)
    ("CoffeeInPot" in m) && return (m, false)
    return (fire(m, remove=["BoiledWater", "GroundCoffee", "Filter"], add=["CoffeeInPot"]), true)
end

function send(m::Marking)
    ("Pending" in m) || return (m, false)
    ("Sent" in m) && return (m, false)
    return (fire(m, remove=["Pending"], add=["Sent"]), true)
end

function credit(m::Marking)
    ("Sent" in m) || return (m, false)
    ("Payment" in m) && return (m, false)
    return (fire(m, remove=["Sent"], add=["Payment"]), true)
end

# Carries the model's one guard: Payment must be present, and is not consumed.
function pour_coffee(m::Marking)
    ("Payment" in m) || return (m, false)
    issubset(["CoffeeInPot", "Cup"], m) || return (m, false)
    return (fire(m, remove=["CoffeeInPot", "Cup"]), true)
end

# The canonical firing order. Unlike the interpreter form, nothing here searches
# for it — it is the author's claim about the model.
const SCHEDULE = [
    ("BoilWater", boil_water),
    ("GrindBeans", grind_beans),
    ("BrewCoffee", brew_coffee),
    ("Send", send),
    ("Credit", credit),
    ("PourCoffee", pour_coffee),
]

function main()
    marking = initial_marking()
    step = 0
    for (name, transition) in SCHEDULE
        marking, fired = transition(marking)
        fired || continue
        step += 1
        println("Step #$step: $name => $(render(marking))")
    end
end

main()
