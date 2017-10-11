package(default_visibility = ["//visibility:public"])

load("@com_happyco_rules_node//node:rules.bzl", "node_library", "node_binary")

node_library(
    name = "node_module",
    srcs = ["package.json", "foo.js"],
    deps = [
        "//examples/bar:node_module",
    ]
)

node_binary(
    name="foo",
    script="foo",
    deps = [":node_module"],
)
