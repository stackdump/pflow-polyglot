.PHONY: all help \
        run-go run-rust run-python run-js run-ruby run-julia run-haskell run-bash run-lean \
        parity parity-native generate check-generated \
        bazel-build bazel-test gazelle bazel-clean

# Every program in this repo implements the same Petri net and prints the same
# canonical trace (parity/trace.golden). There are five forms — interpreter,
# lambda, generated, contract, proof — across ten languages; see FORMS.md.

help:
	@echo "Running implementations:"
	@echo "  make all              run every form in every locally available language"
	@echo "  make run-go           run all five Go forms (same for rust/python/js)"
	@echo "  make run-ruby         run all three Ruby forms (same for julia/haskell)"
	@echo "  make run-lean         run all four Lean forms (same for bash)"
	@echo ""
	@echo "Parity gates:"
	@echo "  make parity           bazel test //... — 20 in-graph programs + codegen drift"
	@echo "  make parity-native    ruby/julia/haskell/bash against the golden trace"
	@echo ""
	@echo "Code generation:"
	@echo "  make generate         regenerate <lang>/generated + parity/reachability.golden"
	@echo "  make check-generated  fail if any generated artifact is stale"

all: run-go run-rust run-python run-js run-bash run-ruby run-julia run-haskell run-lean

# --- per-language runners ---------------------------------------------------
#
# Each prints the same six lines, five (or three, or four) times over.

run-go:
	@echo "--- go ---"
	@cd golang && for form in interpreter lambda contract generated proof; do \
		echo "[go/$$form]"; go run ./$$form; done

run-rust:
	@echo "--- rust ---"
	@for form in interpreter lambda contract generated proof; do \
		echo "[rust/$$form]"; cargo run --quiet --manifest-path rust/Cargo.toml --bin $$form; done

run-python:
	@echo "--- python ---"
	@echo "[python/interpreter]"; python3 python/interpreter.py
	@echo "[python/lambda]";      python3 python/lambda_form.py
	@echo "[python/contract]";    python3 python/contract.py
	@echo "[python/generated]";   python3 python/generated.py
	@echo "[python/proof]";       python3 python/proof.py

run-js:
	@echo "--- javascript ---"
	@for form in interpreter lambda contract generated proof; do \
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
	@for form in interpreter lambda contract proof; do \
		echo "[bash/$$form]"; bash bash/$$form.sh; done

run-lean:
	@command -v lean >/dev/null 2>&1 || { echo "--- lean --- SKIPPED (no lean)"; exit 0; }; \
	echo "--- lean ---"; \
	for form in interpreter lambda contract proof; do \
		echo "[lean/$$form]"; lean --run lean/$$form.lean; done

# --- parity gates -----------------------------------------------------------
#
# `parity` is the real gate: Bazel builds all 20 in-graph programs under
# hermetic toolchains (Go 1.26.0 / Rust 1.86.0 / Node 22.14.0 / CPython 3.12),
# runs each one, and diffs its stdout against parity/trace.golden. Pins match
# the ecosystem-wide line so actions share the bazel.stackdump.com remote cache.
#
# `parity-native` covers what Bazel does not: ruby, julia, haskell, bash, lean.
# It needs system toolchains and SKIPs the ones that are missing.

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
# model.json is the source of truth for the generated form and for
# parity/reachability.golden, the net's full reachable state space. Regenerate
# after changing it; check-generated is what fails the build when you forget.

generate:
	go run ./tools/codegen -lang go       -out golang/generated/main.go   model.json
	go run ./tools/codegen -lang rust     -out rust/src/bin/generated.rs  model.json
	go run ./tools/codegen -lang python   -out python/generated.py        model.json
	go run ./tools/codegen -lang js       -out javascript/src/generated.js model.json
	go run ./tools/codegen -lang solidity -out solidity/generated.sol     model.json
	go run ./tools/codegen -lang lean     -out lean/proof.lean            model.json
	go run ./tools/codegen/reachability   -out parity/reachability.golden model.json

check-generated:
	bazel test //tools/codegen:all
