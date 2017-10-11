#!/bin/sh
if [ -f $1/package-lock.json ]; then
  cd $1
  node -p 'deps=require("./package-lock.json").dependencies||{};o={};for (d of Object.keys(deps)) { o[d] = deps[d].version }; JSON.stringify(o)'
elif [ -f $1/package.json ]; then
  cd $1
  node -p 'deps=require("./package.json").dependencies||{};o=[];for (d of Object.keys(deps)) { o.push("@npm//" + d) }; if (o.length > 0) { JSON.stringify(o) }'
  node -p 'deps=require("./package.json").devDependencies||{};o=[];for (d of Object.keys(deps)) { o.push("@npm//" + d) }; if (o.length > 0) { JSON.stringify(o) }'
else
  echo "Usage: deps <path to package folder>"
  echo
  echo "Folder should contain either package-lock.json or package.json"
fi
