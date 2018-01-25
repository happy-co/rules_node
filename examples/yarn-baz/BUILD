package(default_visibility = ["//visibility:public"])

load("@com_happyco_rules_node//node:rules.bzl", "node_library", "node_binary")

node_library(
    name = "node_module",
    package_name = "examples-baz",
    srcs = glob(["package.json", "*.js"]),
    deps = ["@yarn//chalk:node_module", "@yarn_scoped//:node_modules"],
)

node_binary(
  name = "baz",
  script = "baz",
  deps = [":node_module"],
)

exports_files(["package.json", "yarn.lock"])
