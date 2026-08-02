#!/usr/bin/env bash
# Parity check for the implementations Bazel does not cover: ruby, julia,
# haskell, bash and lean (FORMS.md). These need a system toolchain rather than
# a hermetic one, so this runs outside `bazel test` — `make parity-native`.
#
# A missing toolchain SKIPs rather than fails, so this is usable on a box that
# has only some of them. It reports the skips loudly: a run where everything
# skipped exits 0 but says so, and never claims parity it did not check.
#
# usage: check_native.sh [<repo-root>]
set -uo pipefail

root="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
golden="$root/parity/trace.golden"

if [[ ! -f $golden ]]; then
  echo "FATAL: golden trace not found: $golden" >&2
  exit 1
fi

status=0
checked=0
skipped=()

# run <label> <tool> <command...>
run() {
  local label=$1 tool=$2
  shift 2

  if ! command -v "$tool" >/dev/null 2>&1; then
    skipped+=("$label (no $tool)")
    return
  fi

  checked=$((checked + 1))
  local actual
  actual=$(mktemp)
  if ! "$@" >"$actual" 2>"$actual.err"; then
    echo "FAIL [$label]: exited non-zero" >&2
    sed 's/^/    /' "$actual.err" >&2
    status=1
    rm -f "$actual" "$actual.err"
    return
  fi

  if diff -u --label "trace.golden" --label "$label" "$golden" "$actual" >"$actual.diff"; then
    echo "ok   [$label] trace matches golden"
  else
    echo "FAIL [$label]: trace differs from golden" >&2
    sed 's/^/    /' "$actual.diff" >&2
    status=1
  fi
  rm -f "$actual" "$actual.err" "$actual.diff"
}

run bash-interpreter bash bash "$root/bash/interpreter.sh"
run bash-lambda bash bash "$root/bash/lambda.sh"
run bash-contract bash bash "$root/bash/contract.sh"
run bash-proof bash bash "$root/bash/proof.sh"

run ruby-interpreter ruby ruby "$root/ruby/interpreter.rb"
run ruby-lambda ruby ruby "$root/ruby/lambda.rb"
run ruby-contract ruby ruby "$root/ruby/contract.rb"

run julia-interpreter julia julia "$root/julia/interpreter.jl"
run julia-lambda julia julia "$root/julia/lambda.jl"
run julia-contract julia julia "$root/julia/contract.jl"

# runghc compiles and runs in one step, so nothing is left behind.
run haskell-interpreter runghc runghc "$root/haskell/interpreter.hs"
run haskell-lambda runghc runghc "$root/haskell/lambda.hs"
run haskell-contract runghc runghc "$root/haskell/contract.hs"

# `lean --run` elaborates and runs `main` in one step. Note that elan puts lean
# on the PATH via ~/.profile, so a non-login shell may SKIP these even on a box
# where Lean is installed.
run lean-interpreter lean lean --run "$root/lean/interpreter.lean"
run lean-lambda lean lean --run "$root/lean/lambda.lean"
run lean-contract lean lean --run "$root/lean/contract.lean"
run lean-proof lean lean --run "$root/lean/proof.lean"

if [[ ${#skipped[@]} -gt 0 ]]; then
  echo
  echo "SKIPPED ${#skipped[@]} (toolchain not installed):"
  printf '  - %s\n' "${skipped[@]}"
fi

echo
if [[ $status -ne 0 ]]; then
  echo "FAILED: native parity check"
elif [[ $checked -eq 0 ]]; then
  echo "NOTHING CHECKED: no native toolchain available — this is not a pass"
else
  echo "PASS: $checked native implementations agree with the golden trace"
fi

exit $status
