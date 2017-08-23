@require "github.com/jkroso/AsyncBuffer.jl" asyncpipe Buffer AsyncBuffer

const whitespace = " \t\n\r"
const digits = "0123456789+-"
isdigit(n::Char) = n in digits

skipwhitespace(io::IO) =
  while true
    c = read(io, Char)
    c in whitespace || return c
  end

parse(json::AbstractString) = parse(IOBuffer(json))
parse(io::IO, c::Char=skipwhitespace(io)) = begin
  if     c == '"' parse_string(io)
  elseif c == '{' parse_dict(io)
  elseif c == '[' parse_vec(io)
  elseif isdigit(c) || c == '+' || c == '-' parse_number(c, io)
  elseif c == 't' && read(io, 3) == b"rue" true
  elseif c == 'f' && read(io, 4) == b"alse" false
  elseif c == 'n' && read(io, 3) == b"ull" nothing
  else error("Unexpected char: $c") end
end

function parse_number(c::Char, io::IO)
  buf = Char[c]
  while !eof(io)
    c = read(io, Char)
    if c == '.'
      @assert '.' ∉ buf "malformed number"
    elseif !isdigit(c)
      skip(io, -1)
      break
    end
    push!(buf, c)
  end
  Base.parse(Float32, String(buf))
end

function parse_string(io::IO)
  buf = IOBuffer()
  while true
    c = read(io, Char)
    c == '"' && return String(take!(buf))
    if c == '\\'
      c = read(io, Char)
      if c == 'u' write(buf, unescape_string("\\u$(String(read(io, 4)))")[1]) # Unicode escape
      elseif c == '"'  write(buf, '"' )
      elseif c == '\\' write(buf, '\\')
      elseif c == '/'  write(buf, '/' )
      elseif c == 'b'  write(buf, '\b')
      elseif c == 'f'  write(buf, '\f')
      elseif c == 'n'  write(buf, '\n')
      elseif c == 'r'  write(buf, '\r')
      elseif c == 't'  write(buf, '\t')
      else error("Unrecognized escaped character: $c") end
    else
      write(buf, c)
    end
  end
end

function parse_vec(io::IO)
  vec = Any[]
  while true
    c = read(io, Char)
    c == ']' && return vec
    c in whitespace && continue
    push!(vec, parse(io, c))
    c = skipwhitespace(io)
    c == ']' && return vec
    @assert c == ',' "missing comma"
  end
end

function parse_dict(io::IO)
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

goodIO(io::IO) = asyncpipe(io, Buffer())
goodIO(io::Union{IOBuffer,AsyncBuffer}) = io
goodIO(x::Any) = IOBuffer(x)
Base.parse(::MIME"application/json", data::Any) = parse(goodIO(data))
