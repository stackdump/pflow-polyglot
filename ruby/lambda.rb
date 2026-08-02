# Lambda form: the net is a set of pure marking -> [marking, fired] lambdas
# composed in a fixed schedule. No arrows, no guards list, no enablement
# search — the arcs survive only as control flow inside each lambda.
#
# See FORMS.md; output must match parity/trace.golden.

require 'set'

INITIAL_MARKING = Set['Water', 'CoffeeBeans', 'Filter', 'Cup', 'Pending'].freeze

# Canonical trace rendering: marked places, sorted, comma-joined.
def render(marking)
  marking.to_a.sort.join(',')
end

# Apply an arc pattern to a *copy* of the marking. The lambda form is pure: a
# transition that does not fire returns its input untouched.
def fire(marking, remove: [], add: [])
  (marking - remove) | add
end

BOIL_WATER = lambda do |m|
  return [m, false] unless m.include?('Water')
  return [m, false] if m.include?('BoiledWater')

  [fire(m, remove: ['Water'], add: ['BoiledWater']), true]
end

GRIND_BEANS = lambda do |m|
  return [m, false] unless m.include?('CoffeeBeans')
  return [m, false] if m.include?('GroundCoffee')

  [fire(m, remove: ['CoffeeBeans'], add: ['GroundCoffee']), true]
end

BREW_COFFEE = lambda do |m|
  return [m, false] unless Set['BoiledWater', 'GroundCoffee', 'Filter'].subset?(m)
  return [m, false] if m.include?('CoffeeInPot')

  [fire(m, remove: %w[BoiledWater GroundCoffee Filter], add: ['CoffeeInPot']), true]
end

SEND = lambda do |m|
  return [m, false] unless m.include?('Pending')
  return [m, false] if m.include?('Sent')

  [fire(m, remove: ['Pending'], add: ['Sent']), true]
end

CREDIT = lambda do |m|
  return [m, false] unless m.include?('Sent')
  return [m, false] if m.include?('Payment')

  [fire(m, remove: ['Sent'], add: ['Payment']), true]
end

# Carries the model's one guard: Payment must be present, and is not consumed.
POUR_COFFEE = lambda do |m|
  return [m, false] unless m.include?('Payment')
  return [m, false] unless Set['CoffeeInPot', 'Cup'].subset?(m)

  [fire(m, remove: %w[CoffeeInPot Cup]), true]
end

# The canonical firing order. Unlike the interpreter form, nothing here searches
# for it — it is the author's claim about the model.
SCHEDULE = [
  ['BoilWater', BOIL_WATER],
  ['GrindBeans', GRIND_BEANS],
  ['BrewCoffee', BREW_COFFEE],
  ['Send', SEND],
  ['Credit', CREDIT],
  ['PourCoffee', POUR_COFFEE]
].freeze

def main
  marking = INITIAL_MARKING
  step = 0
  SCHEDULE.each do |name, transition|
    marking, fired = transition.call(marking)
    next unless fired

    step += 1
    puts "Step ##{step}: #{name} => #{render(marking)}"
  end
end

main if __FILE__ == $PROGRAM_NAME
