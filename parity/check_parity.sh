#!/usr/bin/env bash
# Cross-language parity gate.
#
# Runs every in-graph implementation of the coffee-machine Petri net and asserts
# that each one emits the byte-identical canonical trace in trace.golden. The
# implementations are independent rewrites, so an identical trace is a real
# claim about the model, not a shared-code tautology.
#
# usage: check_parity.sh <golden> <lang>=<binary> [<lang>=<binary> ...]
set -uo pipefail

golden="$1"
shift

if [[ ! -f "$golden" ]]; then
  echo "FATAL: golden trace not found: $golden" >&2
  exit 1
fi

status=0
declare -a langs=()

for spec in "$@"; do
  lang="${spec%%=*}"
  bin="${spec#*=}"
  langs+=("$lang")

  if [[ ! -x "$bin" ]]; then
    echo "FAIL [$lang]: binary not executable: $bin" >&2
    status=1
    continue
  fi

  actual_file="${TEST_TMPDIR:-/tmp}/trace.${lang}"
  if ! "$bin" > "$actual_file" 2>"${actual_file}.err"; then
    echo "FAIL [$lang]: implementation exited non-zero" >&2
    sed 's/^/    /' "${actual_file}.err" >&2
    status=1
    continue
  fi

  if diff -u --label "trace.golden" --label "$lang" "$golden" "$actual_file" > "${actual_file}.diff"; then
    echo "ok   [$lang] trace matches golden"
  else
    echo "FAIL [$lang]: trace differs from golden" >&2
    sed 's/^/    /' "${actual_file}.diff" >&2
    status=1
  fi
done

if [[ ${#langs[@]} -lt 2 ]]; then
  echo "FATAL: parity needs at least 2 implementations, got ${#langs[@]}" >&2
  exit 1
fi

if [[ $status -eq 0 ]]; then
  echo "PASS: ${#langs[@]} implementations agree (${langs[*]})"
fi

exit $status
