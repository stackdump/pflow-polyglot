.PHONY: all run-rust run-bash run-python run-js run-ruby run-julia run-haskell

all: run-rust run-bash run-python run-js run-ruby run-julia

run-rust:
	@echo ---
	@echo "Running Rust implementation..."
	cargo run --manifest-path rust/Cargo.toml

run-bash:
	@echo ---
	@echo "Running Bash implementation..."
	bash bash/main.sh

run-python:
	@echo ---
	@echo "Running Python implementation..."
	python3 python/main.py

run-js:
	@echo ---
	@echo "Running JavaScript implementation..."
	node javascript/src/main.js

run-ruby:
	@echo ---
	@echo "Running Ruby implementation..."
	ruby ruby/main.rb

run-julia:
	@echo ---
	@echo "Running Julia implementation..."
	julia julia/main.jl

run-haskell:
	@echo ---
	@echo "Running Haskell implementation..."
	ghc haskell/main.hs -o haskell/main
	./haskell/main
	rm haskell/main haskell/main.hi haskell/main.o