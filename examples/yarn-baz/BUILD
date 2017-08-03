package(default_visibility = ["//visibility:public"])

load("//node:rules.bzl", "node_library", "node_binary")

node_library(
    name = "baz_library",
    package_name = "examples-baz",
    srcs = glob(["package.json", "*.js"]),
    deps = ["@yarn//chalk"],
)

node_binary(
  name = "baz",
  script = "baz",
  deps = [":baz_library"],
)

exports_files(["package.json", "yarn.lock"])
