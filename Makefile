
dependencies: dependencies.json
	@packin install --folder $@ --meta $<
	@ln -snf .. $@/parse-json

test: dependencies
	@$</jest/bin/jest test

bench: dependencies
	@julia bench.jl

.PHONY: test bench
