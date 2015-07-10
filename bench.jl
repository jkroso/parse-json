@require "." parse => parseA
import JSON.parse
using Benchmark

const file = realpath("Readme.ipynb")
const src = readall(file)
const buf = IOBuffer(src)

compare([
  parseJSON() = (parseA(buf);seekstart(buf)),
  standard() = parse(src)
], 200) |> println
