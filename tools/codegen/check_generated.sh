#!/usr/bin/env bash
# Fails if any checked-in file under <lang>/generated/ has drifted from what
# tools/codegen produces from model.json right now.
#
# The generated form only means anything if the code and the model agree. This
# is what stops someone editing generated output by hand (or changing the model
# and forgetting to regenerate) — either way the diff shows up here rather than
# as a silently wrong trace.
#
# usage: check_generated.sh <codegen-binary> <model.json> <lang>=<file> ...
set -uo pipefail

codegen="$1"
model="$2"
shift 2

status=0
checked=0

for spec in "$@"; do
  lang="${spec%%=*}"
  file="${spec#*=}"
  checked=$((checked + 1))

  actual="${TEST_TMPDIR:-/tmp}/regenerated.${lang}"
  if ! "$codegen" -lang "$lang" -out "$actual" "$model"; then
    echo "FAIL [$lang]: codegen exited non-zero" >&2
    status=1
    continue
  fi

  if diff -u --label "$file (checked in)" --label "$lang (regenerated)" "$file" "$actual"; then
    echo "ok   [$lang] $file is up to date"
  else
    echo "FAIL [$lang]: $file is stale — run 'make generate'" >&2
    status=1
  fi
done

if [[ $checked -eq 0 ]]; then
  echo "FATAL: no generated files to check" >&2
  exit 1
fi

if [[ $status -eq 0 ]]; then
  echo "PASS: $checked generated files match model.json"
fi

exit $status
