@require "github.com/BioJulia/BufferedStreams.jl" peek BufferedInputStream

const whitespace = UInt8[" \t\n\r"...]
const digits = UInt8["0123456789+-"...]
isdigit(n::UInt8) = n in digits

function skipwhitespace(io::BufferedInputStream)
  while true
    c = read(io, UInt8)
    c in whitespace || return c
  end
end

parse(json::AbstractString) = parse(IOBuffer(json))
parse(json::IO) = parse(BufferedInputStream(json))

function parse(io::BufferedInputStream)
  c = skipwhitespace(io)
  if     c == '"' parse_string(io)
  elseif c == '{' parse_dict(io)
  elseif c == '[' parse_vec(io)
  elseif isdigit(c) || c == '+' || c == '-' parse_number(c, io)
  elseif c == 't' && readbytes(io, 3) == ["rue"... ] true
  elseif c == 'f' && readbytes(io, 4) == ["alse"...] false
  elseif c == 'n' && readbytes(io, 3) == ["ull"... ] nothing
  else error("Unexpected char: $(convert(Char, c))") end
end

test("primitives") do
  @test !parse("false")
  @test parse("true")
  @test parse("null") == nothing
end

function parse_number(c::UInt8, io::BufferedInputStream)
  Type = Int32
  buf = UInt8[c]
  while !eof(io)
    c = peek(io)
    if c == '.'
      @assert Type == Int32 "malformed number"
      Type = Float32
    elseif !isdigit(c)
      break
    end
    read(io, UInt8)
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

function parse_string(io::BufferedInputStream)
  buf = IOBuffer()
  while true
    c = read(io, UInt8)
    c == '"' && return takebuf_string(buf)
    if c == '\\'
      c = read(io, UInt8)
      if c == 'u' write(buf, unescape_string("\\u$(utf8(readbytes(io, 4)))")[1]) # Unicode escape
      elseif c == '"'  write(buf, '"' )
      elseif c == '\\' write(buf, '\\')
      elseif c == '/'  write(buf, '/' )
      elseif c == 'b'  write(buf, '\b')
      elseif c == 'f'  write(buf, '\f')
      elseif c == 'n'  write(buf, '\n')
      elseif c == 'r'  write(buf, '\r')
      elseif c == 't'  write(buf, '\t')
      else error("Unrecognized escaped character: $(convert(Char, c))") end
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

function parse_vec(io::BufferedInputStream)
  vec = Any[]
  while true
    c = peek(io)
    c == ']' && (read(io, UInt8); return vec)
    c in whitespace && (read(io, UInt8); continue)
    push!(vec, parse(io))
    c = skipwhitespace(io)
    c == ']' && return vec
    @assert c == ',' "missing comma"
  end
end

test("Vector") do
  @test parse("[]") == []
  @test parse("[1]") == Any[1]
  @test parse("[1,2]") == Any[1,2]
  @test parse("[ 1, 2 ]") == Any[1,2]
end

function parse_dict(io::BufferedInputStream)
  dict = Dict{AbstractString,Any}()
  while true
    c = skipwhitespace(io)
    c == '}' && return dict
    @assert c == '"' "dictionary keys must be strings"
    key = parse_string(io)
    @assert skipwhitespace(io) == ':' "missing semi-colon"
    dict[key] = parse(io)
    c = skipwhitespace(io)
    c == '}' && return dict
    @assert c == ',' "missing comma"
  end
end

test("Dict") do
  @test parse("{}") == Dict{AbstractString,Any}()
  @test open(parse, "Readme.ipynb")["metadata"]["language_info"]["name"] == "julia"
end

Base.parse(::MIME"application/json", io::IO) = parse(io)
