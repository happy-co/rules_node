<table><tr>
<td><img src="https://github.com/pubref/rules_protobuf/blob/master/images/bazel.png" width="120"/></td>
<td><img src="https://nodejs.org/static/images/logo.svg" width="120"/></td>
</tr><tr>
<td>Bazel</td>
<td>NodeJs</td>
</tr></table>

# `rules_node` [![Build Status](https://travis-ci.org/happy-co/rules_node.svg?branch=master)](https://travis-ci.org/happy-co/rules_node)

These rules are derived from [org_pubref_rules_node](https://github.com/pubref/rules_node) but updated to work with sandboxed builds and allow more complex node dependency graphs.

## Getting started
Put `rules_node` in your `WORKSPACE` and load the main repository
dependencies.  This will download the nodejs toolchain including
`node` (6.6.x) and `npm` (5.x).

```python
git_repository(
    name = "com_happyco_rules_node",
    remote = "https://github.com/happy-co/rules_node.git",
    commit = "{HEAD}", # replace with latest version
)

load("@com_happyco_rules_node//node:rules.bzl", "node_repositories")

node_repositories()
```

# Rules

| Rule | Description |
| ---: | :---------- |
| [node_repositories](#node_repositories) | Install node toolchain. |
| [npm_repository](#npm_repository) | Install a set of npm dependencies. |
| [npm_library](#npm_library) | Install a set of npm dependencies. |
| [node_library](#node_library) | Define a local npm module. |
| [node_binary](#node_binary) | Build or execute a nodejs script. |
| [ts_compile](#ts_compile) | Build typescript. |
| [ts_library](#ts_library) | Build a local npm module with typescript. |


## node_repositories

WORKSPACE rule that downloads and configures the node toolchain
(`node`, `npm` and `tsc`).

Version defaults are as follows:

| Tool | Version |
| :--- | ---:--- |
| node | 6.6.0 |
| npm | 5.1.0 |
| typescript | 2.4.1 |

## npm_repository

Load a set of npm dependencies as node_libraries in an external workspace.
For example:

```python
# In WORKSPACE
load("@com_happyco_rules_node//node:rules.bzl", "npm_repository")

npm_repository(
    name = "npm_react_stack",
    deps = {
        "react": "15.3.2",
        "react-dom": "15.3.2",
    },
)
```

You can then refer to `@npm_react_stack//react` in the `deps`
attribute of a `node_binary` or `node_library` rule.

## node_library

This rule accepts a list of `srcs` (any file types) and other configuration
attributes and produces a node package tgz within `bazel-bin`.  The name of the
module is taken by munging the package label, substituting `/` (slash) with `-`
(dash) or may be specified with teh `package_name` attribute. For example:

```python
load("//node:rules.bzl", "node_library")

node_library(
    name = "baz_library",
    srcs = [
        "qux.js",
    ],
)
```

The local modules can be `require()`'d in another module as follows:

```js
var baz = require("examples-baz");
console.log('Hello, ' + baz());
```

This packaging/install cycle occurs on demand and is a nicer way to
develop nodejs applications with clear dependency requirements.  Bazel
makes this very clean and convenient.

## npm_library

This rule allows a node package tgz to be provided as a dependency to
other node rules. It is used internally by `npm_repository` but is exposed
if you would prefer to have greater control over packages (for example to
use `http_archive` to verify the package).

## node_binary

Creates an executable script that will run the node script named in the
`script` attribute. Dependencies are installed into a local node context and
a shell script generated that ensures the correct node and context are used.

```python
load("@com_happyco_rules_node//node:rules.bzl", "node_binary")

node_binary(
    name = "baz",
    script = "baz",
    deps = [
        "//examples/baz:baz_library",
    ],
)
```

## ts_compile

Compiles typescript sources to javascript (with declaration and source map files).
The result of this can be provided as a source to `node_library` or use
`ts_library` as a convenience.

```python
load("@com_happyco_rules_node//node:rules.bzl", "ts_compile", "node_library")

ts_compile(
    name = "bar_library_ts",
    srcs = ["bar.ts"],
    target = "ES5",
    strict = True,
    deps = [
        "//examples/baz:baz_library",
    ],
)

node_library(
    name = "bar_library",
    package_name = "examples-bar",
    srcs = ["package.json", ":bar_library_ts"],
    deps = ["//examples/baz:baz_library"],
)
```

## ts_library

Macro to compile typescript sources and build to a local npm module.
The following example is equivalent to the two steps above.

```python
load("@com_happyco_rules_node//node:rules.bzl", "ts_compile")

ts_library(
    name = "bar_library",
    ts_srcs = ["bar.ts"],
    target = "ES5",
    strict = True,
    package_name = "examples-bar",
    node_srcs = ["package.json"],
    deps = ["//examples/baz:baz_library"],
)
```
