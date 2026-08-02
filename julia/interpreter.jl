# Interpreter form: the net is runtime data (arrows, guards) and a scheduler
# searches for an enabled transition. See FORMS.md; output must match
# parity/trace.golden.
#
# The enum members carry the canonical CamelCase names directly, so `string`
# gives the trace spelling with no name table.

@enum State begin
    Water
    BoiledWater
    CoffeeBeans
    GroundCoffee
    Filter
    CoffeeInPot
    Pending
    Sent
    Payment
    Cup
end

@enum Action begin
    BoilWater
    GrindBeans
    BrewCoffee
    PourCoffee
    Send
    Credit
end

# A node is either a place or a transition; exactly one field is set.
struct Node
    place::Union{State,Nothing}
    transition::Union{Action,Nothing}
end

Node(; place=nothing, transition=nothing) = begin
    if isnothing(place) && isnothing(transition)
        throw(ArgumentError("either place or transition must be provided"))
    elseif !isnothing(place) && !isnothing(transition)
        throw(ArgumentError("only one of place or transition may be provided"))
    end
    Node(place, transition)
end

struct Arrow
    from::Node
    to::Node
end

struct Guard
    from::Node
    to::Node
end

struct CoffeeMachine
    state::Set{State}
    arrows::Vector{Arrow}
    guards::Vector{Guard}
end

CoffeeMachine() = CoffeeMachine(
    Set([Water, CoffeeBeans, Filter, Cup, Pending]),
    [
        Arrow(Node(place=Water), Node(transition=BoilWater)),
        Arrow(Node(transition=BoilWater), Node(place=BoiledWater)),
        Arrow(Node(place=CoffeeBeans), Node(transition=GrindBeans)),
        Arrow(Node(transition=GrindBeans), Node(place=GroundCoffee)),
        Arrow(Node(place=BoiledWater), Node(transition=BrewCoffee)),
        Arrow(Node(place=GroundCoffee), Node(transition=BrewCoffee)),
        Arrow(Node(place=Filter), Node(transition=BrewCoffee)),
        Arrow(Node(transition=BrewCoffee), Node(place=CoffeeInPot)),
        Arrow(Node(place=CoffeeInPot), Node(transition=PourCoffee)),
        Arrow(Node(place=Cup), Node(transition=PourCoffee)),
        Arrow(Node(place=Pending), Node(transition=Send)),
        Arrow(Node(transition=Send), Node(place=Sent)),
        Arrow(Node(place=Sent), Node(transition=Credit)),
        Arrow(Node(transition=Credit), Node(place=Payment)),
    ],
    [
        # PourCoffee requires Payment to be marked, and does not consume it.
        Guard(Node(transition=PourCoffee), Node(place=Payment)),
    ],
)

# Canonical trace rendering: marked places, sorted, comma-joined.
filtered_state(cm::CoffeeMachine) = join(sort([string(place) for place in cm.state]), ",")

function guard_fails(cm::CoffeeMachine, state::Set{State}, transition::Action)
    for guard in cm.guards
        if guard.from.transition == transition && !(guard.to.place in state)
            return true
        end
        if guard.to.transition == transition && (guard.from.place in state)
            return true
        end
    end
    return false
end

# prepare_transition is pure: it reports enablement and the places that would
# change, without touching the marking.
function prepare_transition(cm::CoffeeMachine, state::Set{State}, transition::Action)
    places_to_remove = State[]
    places_to_add = State[]

    if guard_fails(cm, state, transition)
        return false, places_to_remove, places_to_add
    end

    for arrow in cm.arrows
        if !isnothing(arrow.from.place) && arrow.to.transition == transition
            if !(arrow.from.place in state)
                return false, places_to_remove, places_to_add
            end
            push!(places_to_remove, arrow.from.place)
        end
        if arrow.from.transition == transition && !isnothing(arrow.to.place)
            # The net is 1-safe: firing into a marked place is not enabled.
            if arrow.to.place in state
                return false, places_to_remove, places_to_add
            end
            push!(places_to_add, arrow.to.place)
        end
    end

    return true, places_to_remove, places_to_add
end

function can_execute(cm::CoffeeMachine, state::Set{State}, transition::Action)
    enabled, _, _ = prepare_transition(cm, state, transition)
    return enabled
end

function execute_transition(cm::CoffeeMachine, transition::Action)
    enabled, places_to_remove, places_to_add = prepare_transition(cm, cm.state, transition)
    enabled || return false

    for place in places_to_remove
        delete!(cm.state, place)
    end
    for place in places_to_add
        push!(cm.state, place)
    end
    return true
end

# Fires the first enabled transition in declaration order until none is enabled.
function execute_process(cm::CoffeeMachine)
    step = 0
    while true
        any_executed = false
        for transition in instances(Action)
            if execute_transition(cm, transition)
                any_executed = true
                step += 1
                println("Step #$step: $(string(transition)) => $(filtered_state(cm))")
                break
            end
        end
        any_executed || break
    end
end

execute_process(CoffeeMachine())
