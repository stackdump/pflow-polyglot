#!/usr/bin/env bash
# Fails if tools/codegen's output depends on the order of model.json's keys.
#
# The generated form claims to be a function of the *net*. JSON objects are
# unordered by spec but ordered on disk, so that claim needs a test: this one
# reorders places, transitions and arcs, regenerates, and requires the output to
# be byte-identical to what is checked in.
#
# Without this, a generator that leaked input order would fail unpredictably —
# Go randomizes map iteration, so the symptom would be a regeneration that
# differs run to run rather than a clean, reproducible diff.
#
# usage: check_permutations.sh <permute-bin> <codegen-bin> <model.json> <lang>=<file> ...
set -uo pipefail

permute="$1"
codegen="$2"
model="$3"
shift 3

tmp="${TEST_TMPDIR:-/tmp}"
status=0
checked=0

# reverse is the permutation that matters most: model.json is alphabetically
# ordered today, so reverse-alphabetical is the order an accidental dependence
# on "sorted input" would most likely survive. The seeds add two arbitrary but
# reproducible orderings on top.
for order in reverse seed:7 seed:1729; do
  permuted="$tmp/model.${order/:/-}.json"

  if ! "$permute" -order "$order" "$model" > "$permuted"; then
    echo "FAIL [$order]: permute exited non-zero" >&2
    status=1
    continue
  fi

  # A permutation that changed nothing would make every check below vacuous.
  if cmp -s "$model" "$permuted"; then
    echo "FAIL [$order]: permuted model is identical to the original — the test would prove nothing" >&2
    status=1
    continue
  fi

  for spec in "$@"; do
    lang="${spec%%=*}"
    file="${spec#*=}"
    checked=$((checked + 1))

    actual="$tmp/regenerated.${order/:/-}.${lang}"
    if ! "$codegen" -lang "$lang" -out "$actual" "$permuted"; then
      echo "FAIL [$order/$lang]: codegen exited non-zero" >&2
      status=1
      continue
    fi

    if diff -u --label "$file (checked in)" --label "$lang (from $order-permuted model)" "$file" "$actual"; then
      echo "ok   [$order/$lang] $file"
    else
      echo "FAIL [$order/$lang]: output depends on model.json key order" >&2
      status=1
    fi
  done
done

if [[ $checked -eq 0 ]]; then
  echo "FATAL: nothing was checked" >&2
  exit 1
fi

if [[ $status -eq 0 ]]; then
  echo "PASS: $checked regenerations across 3 permutations are byte-identical"
fi

exit $status
