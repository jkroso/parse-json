dependencies:
	mkdir $@ && ln -snf .. $@/parse-json

test: dependencies
	@jest index.jl

bench: dependencies
	@julia bench.jl

.PHONY: test bench
