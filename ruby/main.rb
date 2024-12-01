require 'set'

class CoffeeMachine
  State = {
    Water: :Water,
    BoiledWater: :BoiledWater,
    CoffeeBeans: :CoffeeBeans,
    GroundCoffee: :GroundCoffee,
    Filter: :Filter,
    CoffeeInPot: :CoffeeInPot,
    Pending: :Pending,
    Sent: :Sent,
    Payment: :Payment,
    Cup: :Cup
  }

  Action = {
    BoilWater: :BoilWater,
    GrindBeans: :GrindBeans,
    BrewCoffee: :BrewCoffee,
    PourCoffee: :PourCoffee,
    Send: :Send,
    Credit: :Credit
  }

  INITIAL_STATE = [
    State[:Water],
    State[:CoffeeBeans],
    State[:Filter],
    State[:Cup],
    State[:Pending]
  ]

  Arrow = Struct.new(:from, :to)
  Guard = Struct.new(:from, :to)

  def initialize
    @state = INITIAL_STATE.to_set
    @arrows = [
      Arrow.new({ place: State[:Water] }, { transition: Action[:BoilWater] }),
      Arrow.new({ transition: Action[:BoilWater] }, { place: State[:BoiledWater] }),
      Arrow.new({ place: State[:CoffeeBeans] }, { transition: Action[:GrindBeans] }),
      Arrow.new({ transition: Action[:GrindBeans] }, { place: State[:GroundCoffee] }),
      Arrow.new({ place: State[:BoiledWater] }, { transition: Action[:BrewCoffee] }),
      Arrow.new({ place: State[:GroundCoffee] }, { transition: Action[:BrewCoffee] }),
      Arrow.new({ place: State[:Filter] }, { transition: Action[:BrewCoffee] }),
      Arrow.new({ transition: Action[:BrewCoffee] }, { place: State[:CoffeeInPot] }),
      Arrow.new({ place: State[:CoffeeInPot] }, { transition: Action[:PourCoffee] }),
      Arrow.new({ place: State[:Cup] }, { transition: Action[:PourCoffee] }),
      Arrow.new({ place: State[:Pending] }, { transition: Action[:Send] }),
      Arrow.new({ transition: Action[:Send] }, { place: State[:Sent] }),
      Arrow.new({ place: State[:Sent] }, { transition: Action[:Credit] }),
      Arrow.new({ transition: Action[:Credit] }, { place: State[:Payment] })
    ]
    @guards = [
      Guard.new({ transition: Action[:PourCoffee] }, { place: State[:Payment] })
    ]
  end

  def guard_fails(state, transition)
    @guards.any? do |guard|
      (guard[:from][:transition] == transition && !state.include?(guard[:to][:place])) ||
      (guard[:to][:transition] == transition && state.include?(guard[:from][:place]))
    end
  end

  def prepare_transition(state, transition)
    places_to_remove = []
    places_to_add = []

    return [false, places_to_remove, places_to_add] if guard_fails(state, transition)

    @arrows.each do |arrow|
      if arrow[:from][:place] && arrow[:to][:transition] == transition
        return [false, places_to_remove, places_to_add] unless state.include?(arrow[:from][:place])
        places_to_remove << arrow[:from][:place]
      end
      if arrow[:from][:transition] == transition && arrow[:to][:place]
        return [false, places_to_remove, places_to_add] if state.include?(arrow[:to][:place])
        places_to_add << arrow[:to][:place]
      end
    end

    [true, places_to_remove, places_to_add]
  end

  def execute_transition(transition)
    can_execute, places_to_remove, places_to_add = prepare_transition(@state, transition)

    return false unless can_execute

    places_to_remove.each { |place| @state.delete(place) }
    places_to_add.each { |place| @state.add(place) }

    true
  end

  def execute_process
    step = 0
    loop do
      any_executed = false
      Action.values.each do |transition|
        if execute_transition(transition)
          any_executed = true
          step += 1
          puts "Step ##{step}: #{transition} => #{@state.to_a}"
          break
        end
      end
      break unless any_executed
    end
  end
end

# Example usage
cm = CoffeeMachine.new
cm.execute_process