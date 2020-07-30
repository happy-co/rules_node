#!/usr/bin/env node

const args = process.argv.slice(2)
if (args.length !== 4) {
  process.stderr.write(`Usage: ${process.argv[0]} ${process.argv[1]} <info file> <version file> <input file> <output file>\n`)
  process.exit(1)
}

const [infoFile, versionFile, inputFile, outputFile] = args
const values = new Map()

const fs = require('fs')

const readFile = (name, onLine) => {
  fs.readFileSync(name).toString().split("\n").forEach(onLine)
}

readFile(infoFile, line => {
  const [key, value] = line.split(/\s+/, 2)
  values[key] = value || ''
})

readFile(versionFile, line => {
  const [key, value] = line.split(/\s+/, 2)
  values[key] = value || ''
})

const lines = []
readFile(inputFile, line => {
  let l = line.replace(/{(.+)}/, (match, p1) => values[p1])
  lines.push(l)
})
fs.writeFile(outputFile, lines.join('\n'), err => {
  if (err) {
    process.stderr.write(`Could not write output file: ${err.message}\n`)
    process.exit(1)
  }
})
