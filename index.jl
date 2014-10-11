const whitespace = Set(" \t\n\r"...)

parse(json::String) = parse(IOBuffer(json))

function parse(io::IO)
  c = read(io, Char)
  if c in whitespace parse(io)
  elseif c === '"'   parse_string(io)
  elseif c === '{'   parse_dict(io)
  elseif c === '['   parse_vec(io)
  elseif isdigit(c) || c === '+' || c === '-' parse_number(c, io)
  elseif c === 't' && readbytes(io, 3) == ["rue"... ] true
  elseif c === 'f' && readbytes(io, 4) == ["alse"...] false
  elseif c === 'n' && readbytes(io, 3) == ["ull"... ] nothing
  else error("Unexpected char: $c") end
end

function parse_number(c::Char, io::IO)
  parser = parseint
  buf = PipeBuffer(Uint8[c])
  while !eof(io)
    c = read(io, Char)
    if c === '.'
      @assert parser === parseint "malformed number"
      parser = parsefloat
    elseif !isdigit(c)
      skip(io, -1)
      break
    end
    write(buf, c)
  end
  parser(takebuf_string(buf))
end

function parse_string(io::IO)
  buf = IOBuffer()
  while true
    c = read(io, Char)
    c === '"' && return takebuf_string(buf)
    if c === '\\'
      c = read(io, Char)
      if c == 'u' # Unicode escape
        write(buf, unescape_string("\\u$(ascii(readbytes(io, 4)))")[1])
      elseif c === '"'  write(buf, '"' )
      elseif c === '\\' write(buf, '\\')
      elseif c === '/'  write(buf, '/' )
      elseif c === 'b'  write(buf, '\b')
      elseif c === 'f'  write(buf, '\f')
      elseif c === 'n'  write(buf, '\n')
      elseif c === 'r'  write(buf, '\r')
      elseif c === 't'  write(buf, '\t')
      else error("Unrecognized escaped character: $c") end
    else
      write(buf, c)
    end
  end
end

function parse_vec(io::IO)
  vec = {}
  skipwhitespace(io) === ']' && return vec
  skip(io, -1)
  while true
    push!(vec, parse(io))
    c = skipwhitespace(io)
    c === ']' && break
    @assert c === ',' "missing comma"
  end
  return vec
end

function parse_dict(io::IO)
  dict = Dict{String,Any}()
  skipwhitespace(io) === '}' && return dict
  skip(io, -1)
  while true
    key = parse(io)
    @assert isa(key, String) "dictionary keys must be strings"
    @assert skipwhitespace(io) === ':' "missing semi-colon"
    dict[key] = parse(io)
    c = skipwhitespace(io)
    c === '}' && break
    @assert c === ',' "missing comma"
  end
  return dict
end

function skipwhitespace(io::IO)
  while true
    c = read(io, Char)
    c in whitespace || return c
  end
end
