#!/bin/sh
if [ -f ./package-lock.json ]; then
  node -p 'deps=require("./package-lock.json").dependencies;o={};for (d of Object.keys(deps)) { o[d] = deps[d].version }; JSON.stringify(o)'
elif [ -f ./package.json ]; then
  node -p 'deps=require("./package.json").dependencies;o=[];for (d of Object.keys(deps)) { o.push("@npm//" + d) }; JSON.stringify(o)'
  node -p 'deps=require("./package.json").devDependencies;o=[];for (d of Object.keys(deps)) { o.push("@npm//" + d) }; JSON.stringify(o)'
fi
