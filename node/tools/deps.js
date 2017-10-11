#!/usr/bin/env node
var fs = require('fs')
var path = require('path')

var args = process.argv.slice(2)
if (args.length < 1) {
  process.stderr.write("Missing path to node module\n")
  process.exit(1)
}
var modulePath = args[0]
var indeps = args.slice(1)
var pkg = {}
try{
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
    wrapped = fs.readdirSync(path.join(modulePath, "node_modules"))
  } catch (e) {
    // may not have any
  }
  // list deps that aren't wrapped
  var deps = Object.keys(pkg.dependencies).filter(d=>wrapped.indexOf(d)==-1).map(d=>'//'+d+(indeps.indexOf(d)==-1?":node_module":":node_indep"))
  process.stdout.write(JSON.stringify(deps) + "\n")
} else {
  process.stdout.write("[]\n")
}
