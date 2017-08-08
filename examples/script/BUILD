load("//node:rules.bzl", "node_build")

node_build(
    name = "script",
    srcs = ["package.json"],
    outs = ["dist"],
    deps = [
        "//examples/baz:baz_library",
    ]
)
