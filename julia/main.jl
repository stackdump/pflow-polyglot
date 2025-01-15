using Base.Enums

@enum State begin
    WATER
    BOILED_WATER
    COFFEE_BEANS
    GROUND_COFFEE
    FILTER
    COFFEE_IN_POT
    PENDING
    SENT
    PAYMENT
    CUP
end

@enum Action begin
    BOIL_WATER
    GRIND_BEANS
    BREW_COFFEE
    POUR_COFFEE
    SEND
    CREDIT
end

struct Node
    place::Union{State, Nothing}
    transition::Union{Action, Nothing}
end

struct Arrow
    from_node::Node
    to_node::Node
end

struct Guard
    from_node::Node
    to_node::Node
end

struct CoffeeMachine
    state::Set{State}
    arrows::Vector{Arrow}
    guards::Vector{Guard}
end

function Node(;state=nothing, action=nothing)
    if isnothing(state) 
        if isnothing(action)
            throw(ArgumentError("Either state or action must be provided"))
        end
    else
        if !isnothing(action)
            throw(ArgumentError("Only one of state or action must be provided"))
        end
    end
    Node(state, action)
end


CoffeeMachine() = CoffeeMachine(
    Set([WATER, COFFEE_BEANS, FILTER, CUP, PENDING]),
    [
        Arrow(Node(state=WATER), Node(action=BOIL_WATER)),
        Arrow(Node(action=BOIL_WATER), Node(state=BOILED_WATER)),
        Arrow(Node(state=COFFEE_BEANS), Node(action=GRIND_BEANS)),
        Arrow(Node(action=GRIND_BEANS), Node(state=GROUND_COFFEE)),
        Arrow(Node(state=BOILED_WATER), Node(action=BREW_COFFEE)),
        Arrow(Node(state=GROUND_COFFEE), Node(action=BREW_COFFEE)),
        Arrow(Node(state=FILTER), Node(action=BREW_COFFEE)),
        Arrow(Node(action=BREW_COFFEE), Node(state=COFFEE_IN_POT)),
        Arrow(Node(state=COFFEE_IN_POT), Node(action=POUR_COFFEE)),
        Arrow(Node(state=CUP), Node(action=POUR_COFFEE)),
        Arrow(Node(state=PENDING), Node(action=SEND)),
        Arrow(Node(action=SEND), Node(state=SENT)),
        Arrow(Node(state=SENT), Node(action=CREDIT)),
        Arrow(Node(action=CREDIT), Node(state=PAYMENT)),
    ],
    [
        Guard(Node(action=POUR_COFFEE), Node(state=PAYMENT))
    ]
)

function can_execute(cm::CoffeeMachine, state::Set{State}, transition::Action)
    can_execute, _, _ = prepare_transition(cm, state, transition)
    return can_execute
end

function execute_process(cm::CoffeeMachine)
    step = 0
    while true
        any_executed = false
        for transition in instances(Action)
            if execute_transition(cm, transition)
                any_executed = true
                step += 1
                println("Step #$step: $transition => $(cm.state)")
                break
            end
        end
        if !any_executed
            break
        end
    end
end

function guard_fails(cm::CoffeeMachine, state::Set{State}, transition::Action)
    for guard in cm.guards
        if guard.from_node.transition == transition && !(guard.to_node.place in state)
            return true
        end
        if guard.to_node.transition == transition && (guard.from_node.place in state)
            return true
        end
    end
    return false
end

function prepare_transition(cm::CoffeeMachine, state::Set{State}, transition::Action)
    places_to_remove = State[]
    places_to_add = State[]

    if guard_fails(cm, state, transition)
        return false, places_to_remove, places_to_add
    end

    for arrow in cm.arrows
        if ! isnothing(arrow.from_node.place) && arrow.to_node.transition == transition
            if !(arrow.from_node.place in state)
                return false, places_to_remove, places_to_add
            end
            push!(places_to_remove, arrow.from_node.place)
        end
        if arrow.from_node.transition == transition && ! isnothing(arrow.to_node.place)
            if arrow.to_node.place in state
                return false, places_to_remove, places_to_add
            end
            push!(places_to_add, arrow.to_node.place)
        end
    end

    return true, places_to_remove, places_to_add
end

function execute_transition(cm::CoffeeMachine, transition::Action)
    can_execute, places_to_remove, places_to_add = prepare_transition(cm, cm.state, transition)

    if !can_execute
        return false
    end

    for place in places_to_remove
        delete!(cm.state, place)
    end
    for place in places_to_add
        push!(cm.state, place)
    end
    return true
end

cm = CoffeeMachine()
execute_process(cm)
