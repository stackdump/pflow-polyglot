# Contract form: the net is a public API surface. There is no scheduler and no
# schedule — each transition is an entry point that either fires and records an
# event, or raises NotEnabled. The caller decides the order.
#
# This mirrors solidity/contract.sol, where enablement is enforced by `require`
# in a modifier and the event log is the trace.
#
# The driver calls the transitions in the order the canonical scheduling policy
# yields; the methods themselves accept any order and refuse what is not
# enabled.
#
# See FORMS.md; output must match parity/trace.golden.

require 'set'

# Raised when a transition is called in a marking that does not enable it. The
# contract never partially applies: enablement is checked in full before
# anything is mutated.
class NotEnabled < StandardError; end

# Holds the marking and the log of fired transitions. Callers cannot reach the
# marking directly; the only way to change it is a transition.
class CoffeeMachine
  def initialize
    @marked = Set['Water', 'CoffeeBeans', 'Filter', 'Cup', 'Pending']
    @events = []
  end

  def boil_water
    fire('BoilWater', inputs: ['Water'], outputs: ['BoiledWater'])
  end

  def grind_beans
    fire('GrindBeans', inputs: ['CoffeeBeans'], outputs: ['GroundCoffee'])
  end

  def brew_coffee
    fire('BrewCoffee', inputs: %w[BoiledWater GroundCoffee Filter], outputs: ['CoffeeInPot'])
  end

  def send_order
    fire('Send', inputs: ['Pending'], outputs: ['Sent'])
  end

  def credit
    fire('Credit', inputs: ['Sent'], outputs: ['Payment'])
  end

  # Guarded on Payment, which it checks but does not consume.
  def pour_coffee
    fire('PourCoffee', inputs: %w[CoffeeInPot Cup], guards: ['Payment'])
  end

  # The contract's view function: the marked places, sorted.
  def marking
    @marked.to_a.sort.join(',')
  end

  # The log of transitions that have fired, in order.
  attr_reader :events

  private

  # The enablement check every entry point runs first: all inputs marked, all
  # outputs clear, all guards satisfied.
  def require_enabled(name, inputs, outputs, guards)
    inputs.each do |place|
      raise NotEnabled, "#{name}: missing input #{place}" unless @marked.include?(place)
    end
    outputs.each do |place|
      raise NotEnabled, "#{name}: output #{place} already marked" if @marked.include?(place)
    end
    guards.each do |place|
      raise NotEnabled, "#{name}: guard #{place} unsatisfied" unless @marked.include?(place)
    end
  end

  def fire(name, inputs: [], outputs: [], guards: [])
    require_enabled(name, inputs, outputs, guards)
    inputs.each { |place| @marked.delete(place) }
    outputs.each { |place| @marked.add(place) }
    @events << name
    nil
  end
end

def main
  cm = CoffeeMachine.new

  # The driver is the caller, not the machine. Calling these in any other order
  # raises NotEnabled rather than corrupting the marking.
  #
  # `Send` is spelled send_order because Ruby's Object#send is the reflection
  # entry point — overriding it on a public API object is a trap.
  calls = [
    ['BoilWater', -> { cm.boil_water }],
    ['GrindBeans', -> { cm.grind_beans }],
    ['BrewCoffee', -> { cm.brew_coffee }],
    ['Send', -> { cm.send_order }],
    ['Credit', -> { cm.credit }],
    ['PourCoffee', -> { cm.pour_coffee }]
  ]

  step = 0
  calls.each do |name, call|
    begin
      call.call
    rescue NotEnabled
      next
    end
    step += 1
    puts "Step ##{step}: #{name} => #{cm.marking}"
  end
end

main if __FILE__ == $PROGRAM_NAME
