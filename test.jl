@require "." parse

testset("primitives") do
  @test !parse("false")
  @test parse("true")
  @test parse("null") == nothing
end

testset("numbers") do
  @test parse("1") == 1
  @test parse("+1") == 1
  @test parse("-1") == -1
  @test parse("1.0") == 1.0
end

testset("strings") do
  @test parse("\"hi\"") == "hi"
  @test parse("\"\\n\"") == "\n"
  @test parse("\"\\u0026\"") == "&"
end

testset("Vector") do
  @test parse("[]") == []
  @test parse("[1]") == Any[1]
  @test parse("[1,2]") == Any[1,2]
  @test parse("[ 1, 2 ]") == Any[1,2]
end

testset("Dict") do
  @test parse("{}") == Dict{AbstractString,Any}()
  @test open(parse, "Readme.ipynb")["metadata"]["language_info"]["name"] == "julia"
end
