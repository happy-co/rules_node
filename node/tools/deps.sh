#!/bin/sh
node -p 'deps=require("./package-lock.json").dependencies;o={};for (d of Object.keys(deps)) { o[d] = deps[d].version }; JSON.stringify(o)'
