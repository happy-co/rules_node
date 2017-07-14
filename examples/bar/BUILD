load("//node:rules.bzl", "ts_library", "node_binary")

ts_library(
    name = "bar_library",
    ts_srcs = ["bar.ts"],
    package_name = "examples-bar",
    node_srcs = ["package.json"],
    deps = ["//examples/baz:baz_library"],
)
