#!/usr/bin/env bash
# Gates parity/reachability.golden — the full reachable state space of the net.
#
# Three things are checked, in increasing order of what they'd catch:
#
#   1. Drift. Regenerating from model.json reproduces the checked-in file. Same
#      contract as codegen_up_to_date_test: the artifact and the model cannot
#      disagree.
#   2. Permutation invariance. Reordering model.json's keys does not move the
#      space, so the artifact is a function of the net rather than of the file.
#   3. Agreement with parity/trace.golden. The canonical scheduling policy is
#      applied to the state space and the resulting trace is diffed against the
#      trace golden. This is the one that makes the two goldens a pair: the
#      space describes the machine, the trace pins one path through it, and
#      neither can move without the other noticing.
#
# usage: check_reachability.sh <reachability-bin> <permute-bin> <model.json> \
#            <reachability.golden> <trace.golden>
set -uo pipefail

reachability="$1"
permute="$2"
model="$3"
golden="$4"
trace_golden="$5"

tmp="${TEST_TMPDIR:-/tmp}"
status=0

# --- 1. drift ---------------------------------------------------------------
actual="$tmp/reachability.regenerated"
if ! "$reachability" -out "$actual" "$model"; then
  echo "FAIL [drift]: reachability exited non-zero" >&2
  status=1
elif diff -u --label "$golden (checked in)" --label "regenerated" "$golden" "$actual"; then
  echo "ok   [drift] $golden is up to date"
else
  echo "FAIL [drift]: $golden is stale — run 'make generate'" >&2
  status=1
fi

# --- 2. permutation invariance ----------------------------------------------
for order in reverse seed:7 seed:1729; do
  permuted="$tmp/model.${order/:/-}.json"
  if ! "$permute" -order "$order" "$model" > "$permuted"; then
    echo "FAIL [$order]: permute exited non-zero" >&2
    status=1
    continue
  fi

  if cmp -s "$model" "$permuted"; then
    echo "FAIL [$order]: permuted model is identical to the original — the check would prove nothing" >&2
    status=1
    continue
  fi

  actual="$tmp/reachability.${order/:/-}"
  if ! "$reachability" -out "$actual" "$permuted"; then
    echo "FAIL [$order]: reachability exited non-zero" >&2
    status=1
    continue
  fi

  if diff -u --label "$golden (checked in)" --label "from $order-permuted model" "$golden" "$actual"; then
    echo "ok   [$order] state space is invariant under key reordering"
  else
    echo "FAIL [$order]: the state space depends on model.json key order" >&2
    status=1
  fi
done

# --- 3. the two goldens agree -----------------------------------------------
derived="$tmp/trace.derived"
if ! "$reachability" -trace -out "$derived" "$model"; then
  echo "FAIL [trace]: reachability -trace exited non-zero" >&2
  status=1
elif diff -u --label "$trace_golden (checked in)" --label "derived from the state space" "$trace_golden" "$derived"; then
  echo "ok   [trace] the canonical policy over the state space reproduces trace.golden"
else
  echo "FAIL [trace]: reachability.golden and trace.golden disagree" >&2
  status=1
fi

if [[ $status -eq 0 ]]; then
  echo "PASS: state space is up to date, permutation-invariant, and agrees with trace.golden"
fi

exit $status
