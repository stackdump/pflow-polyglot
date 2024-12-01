# python/test/main_test.py

import unittest
from main import CoffeeMachine, State, Action

class TestCoffeeMachine(unittest.TestCase):

    def setUp(self):
        self.cm = CoffeeMachine()

    def test_initial_state(self):
        expected_initial_state = {State.WATER, State.COFFEE_BEANS, State.FILTER, State.CUP, State.PENDING}
        self.assertEqual(self.cm.state, expected_initial_state)

    def test_can_execute_transition(self):
        self.assertTrue(self.cm.can_execute(self.cm.state, Action.BOIL_WATER))
        self.assertFalse(self.cm.can_execute(self.cm.state, Action.POUR_COFFEE))

    def test_execute_transition(self):
        self.assertTrue(self.cm.execute_transition(Action.BOIL_WATER))
        self.assertIn(State.BOILED_WATER, self.cm.state)
        self.assertNotIn(State.WATER, self.cm.state)

    def test_execute_process(self):
        self.cm.execute_process()
        self.assertIn(State.PAYMENT, self.cm.state)
        self.assertNotIn(State.PENDING, self.cm.state)

    def test_pour_coffee_not_enabled(self):
        self.cm.state = {State.CUP, State.PENDING, State.COFFEE_IN_POT}
        self.assertFalse(self.cm.can_execute(self.cm.state, Action.POUR_COFFEE),
                         "Expected PourCoffee not to be enabled in the state [Cup, Pending, CoffeeInPot]")

if __name__ == "__main__":
    unittest.main()