workspace(name = "com_happyco_rules_node")

load("//node:rules.bzl", "node_repositories", "npm_repository", "yarn_repository")

node_repositories()

npm_repository(
    name = "npm",
    deps = {
        "ansi-styles": "3.1.0",
        "chalk": "2.0.1",
        "color-convert": "1.9.0",
        "color-name": "1.1.2",
        "escape-string-regexp": "1.0.5",
        "has-flag": "2.0.0",
        "supports-color": "4.2.0",
    },
)

yarn_repository(
    name = "yarn",
    lockfile = "//examples/yarn-baz:yarn.lock",
    package = "//examples/yarn-baz:package.json",
)

yarn_repository(
    name = "yarn_sealed",
    lockfile = "//examples/sealed:yarn.lock",
    package = "//examples/sealed:package.json",
    seal = True,
)

yarn_repository(
    name = "yarn_scoped",
    lockfile = "//examples/scoped:yarn.lock",
    package = "//examples/scoped:package.json",
)
