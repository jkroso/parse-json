const whitespace = " \t\n\r"

function skipwhitespace(io::IO)
  while true
    c = read(io, Char)
    c in whitespace || return c
  end
end

parse(json::AbstractString) = parse(IOBuffer(json))

function parse(io::IO)
  c = skipwhitespace(io)
  if     c ≡ '"' parse_string(io)
  elseif c ≡ '{' parse_dict(io)
  elseif c ≡ '[' parse_vec(io)
  elseif isdigit(c) || c ≡ '+' || c ≡ '-' parse_number(c, io)
  elseif c ≡ 't' && readbytes(io, 3) == ["rue"... ] true
  elseif c ≡ 'f' && readbytes(io, 4) == ["alse"...] false
  elseif c ≡ 'n' && readbytes(io, 3) == ["ull"... ] nothing
  else error("Unexpected char: $c") end
end

test("primitives") do
  @test !parse("false")
  @test parse("true")
  @test parse("null") ≡ nothing
end

function parse_number(c::Char, io::IO)
  Type = Int32
  buf = UInt8[c]
  while !eof(io)
    c = read(io, Char)
    if c ≡ '.'
      @assert Type ≡ Int32 "malformed number"
      Type = Float32
    elseif !isdigit(c)
      skip(io, -1)
      break
    end
    push!(buf, c)
  end
  Base.parse(Type, ascii(buf))
end

test("numbers") do
  @test parse("1") == 1
  @test parse("+1") == 1
  @test parse("-1") == -1
  @test parse("1.0") == 1.0
end

function parse_string(io::IO)
  buf = IOBuffer()
  while true
    c = read(io, Char)
    c ≡ '"' && return takebuf_string(buf)
    if c ≡ '\\'
      c = read(io, Char)
      if c ≡ 'u' write(buf, unescape_string("\\u$(utf8(readbytes(io, 4)))")[1]) # Unicode escape
      elseif c ≡ '"'  write(buf, '"' )
      elseif c ≡ '\\' write(buf, '\\')
      elseif c ≡ '/'  write(buf, '/' )
      elseif c ≡ 'b'  write(buf, '\b')
      elseif c ≡ 'f'  write(buf, '\f')
      elseif c ≡ 'n'  write(buf, '\n')
      elseif c ≡ 'r'  write(buf, '\r')
      elseif c ≡ 't'  write(buf, '\t')
      else error("Unrecognized escaped character: $c") end
    else
      write(buf, c)
    end
  end
end

test("strings") do
  @test parse("\"hi\"") == "hi"
  @test parse("\"\\n\"") == "\n"
  @test parse("\"\\u0026\"") == "&"
end

function parse_vec(io::IO)
  vec = []
  skipwhitespace(io) ≡ ']' && return vec
  skip(io, -1)
  while true
    push!(vec, parse(io))
    c = skipwhitespace(io)
    c ≡ ']' && break
    @assert c ≡ ',' "missing comma"
  end
  return vec
end

test("Vector") do
  @test parse("[]") == []
  @test parse("[1]") == Any[1]
  @test parse("[1,2]") == Any[1,2]
  @test parse("[ 1, 2 ]") == Any[1,2]
end

function parse_dict(io::IO)
  dict = Dict{AbstractString,Any}()
  skipwhitespace(io) ≡ '}' && return dict
  skip(io, -1)
  while true
    key = parse(io)
    @assert isa(key, AbstractString) "dictionary keys must be strings"
    @assert skipwhitespace(io) ≡ ':' "missing semi-colon"
    dict[key] = parse(io)
    c = skipwhitespace(io)
    c ≡ '}' && break
    @assert c ≡ ',' "missing comma"
  end
  return dict
end

test("Dict") do
  @test parse("{}") == Dict{AbstractString,Any}()
  @test open(parse, "Readme.ipynb")["metadata"]["language_info"]["name"] == "julia"
end

Base.parse(::MIME"application/json", io::IO) = parse(readall(io))
