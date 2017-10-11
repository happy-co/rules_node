package(default_visibility = ["//visibility:public"])

load("@com_happyco_rules_node//node:rules.bzl", "ts_library")

ts_library(
    name = "node_module",
    ts_srcs = ["bar.ts"],
    package_name = "examples-bar",
    node_srcs = ["package.json"],
    deps = ["//examples/baz:node_module"],
)
