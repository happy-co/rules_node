load("@com_happyco_rules_node//node:rules.bzl", "node_build")

node_build(
    name = "script",
    srcs = ["package.json"],
    outs = ["dist"],
    deps = [
        "//examples/baz:node_module",
    ]
)
