// Structural and behavioural analysis of a Model, feeding the generated proof
// form (templates/lean.tmpl). Everything here is computed from the same
// normalized Model the other emitters use, so the theorems the proof form
// states are downstream of exactly one reading of model.json.
package petri

import (
	"math/big"
	"sort"
)

// Invariant is a structural P-invariant: an integer weight vector y over
// Places (same order) with yᵀC = 0, where C is the |P|×|T| incidence matrix
// (C[p][t] = tokens t produces into p minus tokens it consumes from p). The
// weighted token count Σ y[p]·M[p] is then constant along every firing
// sequence — a fact about C alone, independent of the initial marking.
//
// Guards and blockers (read and inhibitor arcs) have no entry in C: they test
// the marking without changing it. See book-pflow-xyz Appendix E, "Where the
// Free Structure Stops".
type Invariant struct {
	Weights []int64 // one per place, in Places order; primitive (gcd 1)
}

// Incidence returns C as Places × Transitions.
func (m Model) Incidence() [][]int64 {
	idx := map[string]int{}
	for i, p := range m.Places {
		idx[p] = i
	}
	c := make([][]int64, len(m.Places))
	for i := range c {
		c[i] = make([]int64, len(m.Transitions))
	}
	for j, t := range m.Transitions {
		for _, p := range t.Inputs {
			c[idx[p]][j]--
		}
		for _, p := range t.Outputs {
			c[idx[p]][j]++
		}
	}
	return c
}

// PInvariants returns a basis of the left nullspace of C over the integers:
// every y with yᵀC = 0 is an integer combination of the vectors returned
// (over ℚ; the basis is scaled to primitive integer vectors). It is computed
// by reduced row echelon form of Cᵀ over ℚ, so with Places and Transitions
// sorted the result is a function of the net alone — the permutation test
// holds for it like for everything else codegen emits.
//
// The basis is the canonical "one free variable set to 1" basis of the RREF,
// ordered by the free place's index. It is not guaranteed semi-positive: a
// net that destroys tokens (this one's PourCoffee) has invariants with
// negative entries, and the proof form states them with Int weights.
func (m Model) PInvariants() []Invariant {
	c := m.Incidence()
	nP, nT := len(m.Places), len(m.Transitions)

	// A = Cᵀ, nT rows × nP columns, over ℚ.
	a := make([][]*big.Rat, nT)
	for j := 0; j < nT; j++ {
		a[j] = make([]*big.Rat, nP)
		for i := 0; i < nP; i++ {
			a[j][i] = big.NewRat(c[i][j], 1)
		}
	}

	// RREF.
	pivotCols := []int{}
	row := 0
	for col := 0; col < nP && row < nT; col++ {
		pr := -1
		for r := row; r < nT; r++ {
			if a[r][col].Sign() != 0 {
				pr = r
				break
			}
		}
		if pr < 0 {
			continue
		}
		a[row], a[pr] = a[pr], a[row]
		inv := new(big.Rat).Inv(a[row][col])
		for k := 0; k < nP; k++ {
			a[row][k] = new(big.Rat).Mul(a[row][k], inv)
		}
		for r := 0; r < nT; r++ {
			if r == row || a[r][col].Sign() == 0 {
				continue
			}
			f := new(big.Rat).Set(a[r][col])
			for k := 0; k < nP; k++ {
				a[r][k] = new(big.Rat).Sub(a[r][k], new(big.Rat).Mul(f, a[row][k]))
			}
		}
		pivotCols = append(pivotCols, col)
		row++
	}

	isPivot := map[int]int{} // col -> row
	for r, col := range pivotCols {
		isPivot[col] = r
	}

	var out []Invariant
	for free := 0; free < nP; free++ {
		if _, ok := isPivot[free]; ok {
			continue
		}
		y := make([]*big.Rat, nP)
		for i := range y {
			y[i] = new(big.Rat)
		}
		y[free].SetInt64(1)
		for col, r := range isPivot {
			y[col] = new(big.Rat).Neg(a[r][free])
		}
		out = append(out, Invariant{Weights: primitive(y)})
	}
	sort.SliceStable(out, func(i, j int) bool {
		return firstNonZero(out[i].Weights) < firstNonZero(out[j].Weights)
	})
	return out
}

func firstNonZero(w []int64) int {
	for i, v := range w {
		if v != 0 {
			return i
		}
	}
	return len(w)
}

// primitive scales a rational vector to the integer vector with gcd 1 whose
// first non-zero entry is positive.
func primitive(y []*big.Rat) []int64 {
	l := big.NewInt(1)
	for _, v := range y {
		d := v.Denom()
		g := new(big.Int).GCD(nil, nil, l, d)
		l.Mul(l, new(big.Int).Div(d, g))
	}
	ints := make([]*big.Int, len(y))
	g := new(big.Int)
	for i, v := range y {
		n := new(big.Int).Mul(v.Num(), new(big.Int).Div(l, v.Denom()))
		ints[i] = n
		g.GCD(nil, nil, g, new(big.Int).Abs(n))
	}
	if g.Sign() == 0 {
		g.SetInt64(1)
	}
	out := make([]int64, len(y))
	for i, n := range ints {
		out[i] = new(big.Int).Div(n, g).Int64()
	}
	if k := firstNonZero(out); k < len(out) && out[k] < 0 {
		for i := range out {
			out[i] = -out[i]
		}
	}
	return out
}

// Weighted is Σ inv.Weights[p]·M[p] over the 1-safe marking.
func (m Model) Weighted(inv Invariant, marking Marking) int64 {
	var s int64
	for i, p := range m.Places {
		if marking[p] {
			s += inv.Weights[i]
		}
	}
	return s
}

// Reachable explores the state space under the canonical semantics and
// returns every reachable marking in BFS order, plus the terminal (deadlock)
// markings among them.
func (m Model) Reachable() (all []Marking, deadlocks []Marking) {
	initial := m.InitialMarking()
	seen := map[string]bool{initial.Key(): true}
	frontier := []Marking{initial}
	for len(frontier) > 0 {
		cur := frontier[0]
		frontier = frontier[1:]
		all = append(all, cur)
		enabled := m.EnabledIn(cur)
		if len(enabled) == 0 {
			deadlocks = append(deadlocks, cur)
		}
		for _, name := range enabled {
			t, _ := m.ByName(name)
			next := Fire(cur, t)
			if !seen[next.Key()] {
				seen[next.Key()] = true
				frontier = append(frontier, next)
			}
		}
	}
	return all, deadlocks
}

// ConflictFree reports whether no two transitions share an input place. Such
// a net has no choice, so every maximal firing sequence ends in the same
// marking; the proof form states that marking as a theorem.
func (m Model) ConflictFree() bool {
	consumer := map[string]string{}
	for _, t := range m.Transitions {
		for _, p := range t.Inputs {
			if prev, ok := consumer[p]; ok && prev != t.Name {
				return false
			}
			consumer[p] = t.Name
		}
	}
	return true
}

// --- view for the proof-form template -------------------------------------

// ProofInvariant is one P-invariant rendered for the template.
type ProofInvariant struct {
	Index   int
	Weights []int64
	Terms   []string // "+1·BoiledWater", "-1·Cup" … for the comment
	Initial int64    // Σ y·M₀, the conserved value
}

// Proof is everything the Lean template needs beyond the Model itself.
type Proof struct {
	Model
	Invariants   []ProofInvariant
	ReachCount   int
	Fuel         int // 2^|P|: the BFS bound
	ConflictFree bool
	Deadlocks    []string // canonical keys of the terminal markings
	Final        []string // the unique terminal marking, if ConflictFree && one deadlock
}

// ProofView computes the theorems the proof form will state.
func (m Model) ProofView() Proof {
	p := Proof{Model: m, ConflictFree: m.ConflictFree()}
	p.Fuel = 1 << uint(len(m.Places))
	all, dead := m.Reachable()
	p.ReachCount = len(all)
	initial := m.InitialMarking()
	for i, inv := range m.PInvariants() {
		pi := ProofInvariant{Index: i + 1, Weights: inv.Weights, Initial: m.Weighted(inv, initial)}
		for k, w := range inv.Weights {
			switch {
			case w == 0:
			case w > 0:
				pi.Terms = append(pi.Terms, "+"+itoa(w)+"·"+m.Places[k])
			default:
				pi.Terms = append(pi.Terms, itoa(w)+"·"+m.Places[k])
			}
		}
		p.Invariants = append(p.Invariants, pi)
	}
	for _, d := range dead {
		p.Deadlocks = append(p.Deadlocks, d.Key())
	}
	sort.Strings(p.Deadlocks)
	if len(dead) == 1 {
		for _, pl := range m.Places {
			if dead[0][pl] {
				p.Final = append(p.Final, pl)
			}
		}
	}
	return p
}

func itoa(v int64) string {
	return big.NewInt(v).String()
}
