@require "." parse

suite("strings") do
  @test parse("\"hi\"") == "hi"
  @test parse("\"\n\"") == "\n"
end

suite("numbers") do
  @test parse("1") === 1
  @test parse("+1") === 1
  @test parse("-1") === -1
  @test parse("1.0") === 1.0
end

suite("boolean") do
  @test !parse("false")
  @test parse("true")
end

suite("null") do
  @test parse("null") === nothing
end

suite("Dict") do
  @test parse("{}") == Dict{String,Any}()

  suite("small") do
    d = open(parse, "dependencies.json")
    @test isa(d, Dict{String,Any})
    @test d["development"]["jest"] == "http://github.com/jkroso/jest/tarball/0.0.2"
  end

  suite("large") do
    d = open(parse, "dependencies/mime-db/db.json")
    @test isa(d, Dict{String,Any})
    @test ==(d["application/json"], [
      "extensions" => {"json","map"},
      "compressible" => true,
      "charset" => "UTF-8",
      "source" => "iana"
    ])
    @test open(parse, "Readme.ipynb")["metadata"]["language"] == "Julia"
  end
end

suite("Vector") do
  @test parse("[]") == {}
  @test parse("[1]") == {1}
  @test parse("[1,2]") == {1,2}
  @test parse("[ 1, 2 ]") == {1,2}
end
