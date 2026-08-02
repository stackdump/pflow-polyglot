.PHONY: all help \
        run-go run-rust run-python run-js run-ruby run-julia run-haskell run-bash \
        parity parity-native generate check-generated \
        bazel-build bazel-test gazelle bazel-clean

# Every program in this repo implements the same Petri net and prints the same
# canonical trace (parity/trace.golden). There are four forms — interpreter,
# lambda, generated, contract — across nine languages; see FORMS.md.

help:
	@echo "Running implementations:"
	@echo "  make all              run every form in every locally available language"
	@echo "  make run-go           run all four Go forms (same for rust/python/js)"
	@echo "  make run-ruby         run all three Ruby forms (same for julia/haskell/bash)"
	@echo ""
	@echo "Parity gates:"
	@echo "  make parity           bazel test //... — 16 in-graph programs + codegen drift"
	@echo "  make parity-native    ruby/julia/haskell/bash against the golden trace"
	@echo ""
	@echo "Code generation:"
	@echo "  make generate         regenerate <lang>/generated from model.json"
	@echo "  make check-generated  fail if any generated file is stale"

all: run-go run-rust run-python run-js run-bash run-ruby run-julia run-haskell

# --- per-language runners ---------------------------------------------------
#
# Each prints the same six lines, four (or three) times over.

run-go:
	@echo "--- go ---"
	@cd golang && for form in interpreter lambda contract generated; do \
		echo "[go/$$form]"; go run ./$$form; done

run-rust:
	@echo "--- rust ---"
	@for form in interpreter lambda contract generated; do \
		echo "[rust/$$form]"; cargo run --quiet --manifest-path rust/Cargo.toml --bin $$form; done

run-python:
	@echo "--- python ---"
	@echo "[python/interpreter]"; python3 python/interpreter.py
	@echo "[python/lambda]";      python3 python/lambda_form.py
	@echo "[python/contract]";    python3 python/contract.py
	@echo "[python/generated]";   python3 python/generated.py

run-js:
	@echo "--- javascript ---"
	@for form in interpreter lambda contract generated; do \
		echo "[js/$$form]"; node javascript/src/$$form.js; done

run-ruby:
	@command -v ruby >/dev/null 2>&1 || { echo "--- ruby --- SKIPPED (no ruby)"; exit 0; }; \
	echo "--- ruby ---"; \
	for form in interpreter lambda contract; do \
		echo "[ruby/$$form]"; ruby ruby/$$form.rb; done

run-julia:
	@command -v julia >/dev/null 2>&1 || { echo "--- julia --- SKIPPED (no julia)"; exit 0; }; \
	echo "--- julia ---"; \
	for form in interpreter lambda contract; do \
		echo "[julia/$$form]"; julia julia/$$form.jl; done

run-haskell:
	@command -v runghc >/dev/null 2>&1 || { echo "--- haskell --- SKIPPED (no runghc)"; exit 0; }; \
	echo "--- haskell ---"; \
	for form in interpreter lambda contract; do \
		echo "[haskell/$$form]"; runghc haskell/$$form.hs; done

run-bash:
	@echo "--- bash ---"
	@for form in interpreter lambda contract; do \
		echo "[bash/$$form]"; bash bash/$$form.sh; done

# --- parity gates -----------------------------------------------------------
#
# `parity` is the real gate: Bazel builds all 16 in-graph programs under
# hermetic toolchains (Go 1.26.0 / Rust 1.86.0 / Node 22.14.0 / CPython 3.12),
# runs each one, and diffs its stdout against parity/trace.golden. Pins match
# the ecosystem-wide line so actions share the bazel.stackdump.com remote cache.
#
# `parity-native` covers what Bazel does not: ruby, julia, haskell, bash. It
# needs system toolchains and SKIPs the ones that are missing.

parity: bazel-test

parity-native:
	@./parity/check_native.sh

bazel-build:
	bazel build //...

bazel-test:
	bazel test //...

gazelle:
	bazel run //:gazelle

bazel-clean:
	bazel clean

# --- code generation --------------------------------------------------------
#
# model.json is the source of truth for the generated form. Regenerate after
# changing it; check-generated is what fails the build when you forget.

generate:
	go run ./tools/codegen -lang go       -out golang/generated/main.go   model.json
	go run ./tools/codegen -lang rust     -out rust/src/bin/generated.rs  model.json
	go run ./tools/codegen -lang python   -out python/generated.py        model.json
	go run ./tools/codegen -lang js       -out javascript/src/generated.js model.json
	go run ./tools/codegen -lang solidity -out solidity/generated.sol     model.json

check-generated:
	bazel test //tools/codegen:codegen_up_to_date_test
