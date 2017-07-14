load("//node:rules.bzl", "node_library", "node_binary")

node_library(
    name = "foo_library",
    srcs = ["package.json", "foo.js"],
    deps = [
        "//examples/baz:baz_library",
    ]
)

node_binary(
    name="foo",
    script="foo",
    deps = [":foo_library"],
)
