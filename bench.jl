@require "JSON/src/Parser" parse => parseB
@require "." parse => parseA
using Benchmark

show(compare([
  parseJSON() = open(parseA,"./dependencies/mime-db/db.json"),
  JSON() = parseB(readall("./dependencies/mime-db/db.json"))
], 100))
