load("//node:internal/repositories.bzl", _node_repositories = "node_repositories")
load("//node:internal/npm_repository.bzl", _npm_repository = "npm_repository")
load("//node:internal/yarn_repository.bzl", _yarn_repository = "yarn_repository")
load("//node:internal/bower_repository.bzl", _bower_repository = "bower_repository")
load("//node:internal/node_library.bzl", _node_library = "node_library", _node_module = "node_module")
load("//node:internal/module_group.bzl", _module_group = "module_group", _sealed_module_group = "sealed_module_group")
load("//node:internal/node_binary.bzl", _node_binary = "node_binary")
load("//node:internal/node_build.bzl", _node_build = "node_build")
load("//node:internal/node_install.bzl", _node_install = "node_install")
load("//node:internal/typescript.bzl", _ts_compile = "ts_compile", _ts_library = "ts_library")

node_repositories = _node_repositories
npm_repository = _npm_repository
yarn_repository = _yarn_repository
bower_repository = _bower_repository
node_library = _node_library
node_module = _node_module
module_group = _module_group
sealed_module_group = _sealed_module_group
node_binary = _node_binary
node_build = _node_build
node_install = _node_install
ts_compile = _ts_compile
ts_library = _ts_library
