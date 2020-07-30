#!/usr/bin/env node
var fs = require('fs')
var path = require('path')

var args = process.argv.slice(2)
if (args.length < 1) {
  process.stderr.write("Missing path to node module\n")
  process.exit(1)
}
var modulePath = args[0]
var checkPeers = args[1] === "--checkPeers"
var indeps = args.slice(checkPeers ? 2 : 1)
var pkg = {}
try {
  data = fs.readFileSync(path.join(modulePath, "package.json"), 'utf8')
  process.stderr.write(typeof data)
  if (data) {
    pkg = JSON.parse(data)
  }
} catch (err) {
  if (err.code !== "ENOENT") throw err
}
if (pkg.dependencies) {
  var wrapped = []
  try {
    // A node module must be wrapped if it isn't in the root node_modules directory
    wrapped = fs.readdirSync(path.join(modulePath, "node_modules"))
  } catch (e) {
    // may not have any
  }
  if (checkPeers) {
    wrapped += fs.readdirSync(path.join(modulePath, ".."))
    wrapped += path.basename(path.join(modulePath, "..", ".."))
  }
  // list deps that aren't wrapped
  var fixedDeps = Object.keys(pkg.dependencies).map(d => d[0] == "@" ? d.replace("@", "__AT__").replace("/", "__SLASH__") : d)
  var deps = fixedDeps.filter(d => wrapped.indexOf(d) == -1).map(d => '//' + d + (indeps.indexOf(d) == -1 ? ":node_module" : ":node_indep"))
  process.stdout.write(JSON.stringify(deps) + "\n")
} else {
  process.stdout.write("[]\n")
}
