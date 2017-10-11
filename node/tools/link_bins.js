#!/usr/bin/env node
var fs = require('fs')
var path = require('path')

const BIN_PATH = '.bin'

function symlink(src, dest) {
  try {
    fs.symlinkSync(src, dest)
  } catch (err) {
    if (err.code !== "EEXIST") throw err
  }
}

var args = process.argv.slice(2)
if (args.length != 1) {
  process.stderr.write("Missing path to node_modules\n")
  process.exit(1)
}
var modulesPath = args[0]

var modules = fs.readdirSync(modulesPath)
var binLoc = path.join(modulesPath, BIN_PATH)
try {
  fs.mkdirSync(binLoc)
} catch (err) {
  if (err.code !== "EEXIST") throw err
}
modules.forEach((module) => {
  if (module.startsWith('.')) return
  var pkgLoc = path.join("..", module)
  try {
    var pkg = JSON.parse(fs.readFileSync(path.join(modulesPath, module, "package.json")))
    if (pkg && pkg.bin) {
      if (typeof pkg.bin === "string") {
        var dest = path.join(binLoc, pkg.name)
        var src = path.join(pkgLoc, pkg.bin)
        symlink(src, dest)
      } else {
        for (var scriptName of Object.keys(pkg.bin)) {
          var scriptCmd = pkg.bin[scriptName]
          var dest = path.join(binLoc, scriptName)
          var src = path.join(pkgLoc, scriptCmd)
          symlink(src, dest)
        }
      }
    } else if (pkg && pkg.directories && pkg.directories.bin) {
      fs.readdirSync(path.join(modulesPath, module, pkg.directories.bin)).forEach((script)=>{
        var dest = path.join(binLoc, script)
        var src = path.join(pkgLoc, pkg.directories.bin, script)
        symlink(src, dest)
      })
    }
  } catch (err) {
    if (err.code !== "EEXIST" && err.code !== "ENOTDIR") throw err
  }
})
