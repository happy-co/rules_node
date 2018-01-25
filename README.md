# rules_node [![Build Status](https://travis-ci.org/happy-co/rules_node.svg?branch=master)](https://travis-ci.org/happy-co/rules_node)

These rules are derived from [org_pubref_rules_node](https://github.com/pubref/rules_node)
but substantially reworked to support sandboxed builds and allow more complex
node dependency graphs.

Also supports building Typescript libraries and pulling dependencies from Bower,
NPM and Yarn.

## Getting started
Put `rules_node` in your `WORKSPACE` and load the main repository dependencies.
This will download the nodejs toolchain including `node` (6.x).

```python
git_repository(
    name = "com_happyco_rules_node",
    remote = "https://github.com/happy-co/rules_node.git",
    commit = "v1.0.0", # replace with latest version
)

load("@com_happyco_rules_node//node:rules.bzl", "node_repositories")

node_repositories()
```

## Changes from pre-1.0 release
The 1.0 release has removed support for providing a pre-provisioned `node_modules`
folder (such as by `yarn_repository`) and instead such repositories can be added
directly as dependencies.

To upgrade, remove the `modules` attribute from your build rule and add to `deps`.

Package naming has been simplified to use just the rule name if `package_name`
is unset. To keep the previous auto-munged package name, provide it in the
`package_name` attribute.

# Rules

| Rule | Description |
| ---: | :---------- |
| [node_repositories](#node_repositories) | Install node toolchain. |
| [npm_repository](#npm_repository) | Install a set of npm dependencies. |
| [yarn_repository](#yarn_repository) | Install yarn managed dependencies. |
| [bower_repository](#bower_repository) | Install bower managed dependencies. |
| [node_library](#node_library) | Define a local node module. |
| [node_module](#node_module) | Expose a tgz as a node module. |
| [module_group](#module_group) | Group node modules for easier dependencies. |
| [node_binary](#node_binary) | Build an executable nodejs script. |
| [node_build](#node_build) | Execute a nodejs build script. |
| [node_install](#node_install) | Install a set of node modules (for use as data). |
| [ts_compile](#ts_compile) | Build typescript. |
| [ts_library](#ts_library) | Build a local node module with typescript. |


## node_repositories
WORKSPACE rule that downloads and configures the node toolchain
(`node`, `npm`, `yarn`, `bower` and `tsc`).

Version defaults are as follows:

| Tool | Version |
| :--- | :------ |
| node | 6.11.4 |
| npm | 5.5.1 |
| yarn | 1.2.1 |
| bower | 1.8.2 |
| typescript | 2.5.3 |

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

You can then refer to `@npm_react_stack//react:node_module` in the `deps`
attribute of a `node_binary` or `node_library` rule. You can also
depend on the entire repository as `@npm_react_stack//:node_modules`.

*Note:* if the package contains any files named `build`, they will be renamed
to `build.js` to prevent Bazel interpreting the folder as a package.

### Breaking Dependency Cycles
Often node modules will have cyclic dependencies which need to be broken for
Bazel which prohibits them. Do this by adding an `indeps` attribute.

For example, given a cycle:
```
.-> @npm//d:node_module
|   @npm//es5-ext:node_module
|   @npm//es6-iterator:node_module
`-- @npm//d:node_module
```

You need to apply a break between `es6-iterator` and `d`:

```python
npm_repository(
  name = "npm",
  deps = { "d": "0.1.0" },
  indeps = {
    "es6-iterator": ["d"],
  },
)
```

Be careful not to create a dependency cycle by duplicating the break in your config.
For example, when you see a cycle like this:
```
.-> @npm//es5-ext:node_indep
|   @npm//es6-iterator:node_indep
`-- @npm//es5-ext:node_indep
```

You'll probably find something like this in your config:
```python
npm_repository(
  name = "npm",
  deps = { "es6-iterator": "0.1.0" },
  indeps = {
    "es6-iterator": ["es5-ext"],
    "es5-ext": ["es6-iterator"]
  },
)
```

## yarn_repository
Load a set of yarn managed dependencies. Requires a `package.json` and
`yarn.lock` to be exported from a package
(i.e. `exports_files(["package.json", "yarn.lock"])`)

For example:

```python
# In WORKSPACE
load("@com_happyco_rules_node//node:rules.bzl", "yarn_repository")

yarn_repository(
    name = "yarn-baz",
    package = "//examples/yarn-baz:package.json",
    lockfile = "//examples/yarn-baz:yarn.lock",
)
```

The contents of the repository can be referenced in two ways:

1. Reference the entire `node_modules` folder as `@yarn-baz//:node_modules`
2. Individual modules as `@yarn-baz//module-name:node_module`

Break dependency cycles is the same as for `npm_repository`: by adding an
`indeps` attribute.

*Note:* if the package contains any files named `build`, they will be renamed
to `build.js` to prevent Bazel interpreting the folder as a package.

## bower_repository
Load a set of bower managed dependencies. Requires a `bower.json` to be
exported from a package (i.e. `exports_files(["bower.json"])`)

For example:

```python
# In WORKSPACE
load("@com_happyco_rules_node//node:rules.bzl", "bower_repository")

bower_repository(
    name = "my-bower",
    manifest = "//example:bower.json",
)
```

The contents of the repository are then available as `@my-bower//:bower_components`
for use as a src or other input to other rules.

## node_library
This macro accepts a list of `srcs` (any file types) and other configuration
attributes and produces a node package tgz within `bazel-bin` named
`{name}-package.tar.gz`. The package is also exposed as a `node_module` for use
as a dependency in other packages or rules.

```python
load("@com_happyco_rules_node//node:rules.bzl", "node_library")

node_library(
    name = "node_module",
    package_name = "examples-baz",
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

## node_module
This rule exposes a tgz package as a node module that can be depended on by
other rules.

```python
load("@com_happyco_rules_node//node:rules.bzl", "node_module")

node_module(
    name = "node_module",
    package_name = "examples-baz",
    srcs = [
        "package.tar.gz",
    ],
)
```

## module_group
This rule allows for aggregating multiple `node_module`s as a single name, for
easier dependencies on groups of modules.

```python
load("@com_happyco_rules_node//node:rules.bzl", "module_group")

module_group(
    name = "node_modules",
    srcs = [
        ":foo_library",
        ":bar_library",
    ],
)
```

This rule is used internally by `npm_repository` and `yarn_repository`.

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
        "//examples/baz:node_module",
    ],
)
```

## node_build
This rule allows running arbitrary node scripts to produce a build. By default
executes the `build` script, but this can be overridden with the `script`
attribute.

```python
load("@com_happyco_rules_node//node:rules.bzl", "node_build")

exports_files(["package.json", "yarn.lock"])

node_build(
    name = "script",
    srcs = ["package.json"],
    outs = ["dist"],
    deps = [
        "@yarn-baz//:node_modules",
        "//examples/baz:node_module",
    ],
)
```

## node_install
This rule installs a set of node modules in the named folder (same name as the
rule).

The resultant folder is available as runfiles to other rules. This is most
useful for embedding node modules into another app or for testing.

```python
load("@com_happyco_rules_node//node:rules.bzl", "node_build")

exports_files(["package.json", "yarn.lock"])

node_install(
    name = "my-mods",
    deps = [
        "@yarn-baz//:node_modules",
        "//examples/baz:node_module",
    ],
)

java_binary(
    name="my-server",
    ...
    resources = [":my-mods"],
)
```

## ts_compile
Compiles typescript sources to javascript (with declaration and source map
files). The result of this can be provided as a source to `node_library` or use
`ts_library` as a convenience.

```python
load("@com_happyco_rules_node//node:rules.bzl", "ts_compile", "node_library")

ts_compile(
    name = "bar_library_ts",
    srcs = ["bar.ts"],
    target = "ES5",
    strict = True,
    deps = [
        "//examples/baz:node_module",
    ],
)

node_library(
    name = "node_module",
    package_name = "examples-bar",
    srcs = ["package.json", ":bar_library_ts"],
    deps = ["//examples/baz:node_module"],
)
```

## ts_library
Macro to compile typescript sources and build to a local npm module.
The following example is equivalent to the two steps above.

```python
load("@com_happyco_rules_node//node:rules.bzl", "ts_compile")

ts_library(
    name = "node_module",
    ts_srcs = ["bar.ts"],
    target = "ES5",
    strict = True,
    package_name = "examples-bar",
    node_srcs = ["package.json"],
    deps = ["//examples/baz:node_module"],
)
```

# Tools
A tool is provided to extract dependencies from `package.json` to
Bazel.

Run: `bazel run @com_happyco_rules_node//node/tools:deps <full path to package folder>`

Note, due to bazel runtime environment, the full path is required.
