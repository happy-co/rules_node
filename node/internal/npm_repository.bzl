load("//node:internal/node_utils.bzl", "execute", "node_attrs")

BUILD_FILE = """package(default_visibility = ["//visibility:public"])
load("@com_happyco_rules_node//node:rules.bzl", "npm_library")

npm_library(
    name = "{name}",
    srcs = "{file}",
    deps = {deps})
"""

def _npm_repository_impl(ctx):
    node = ctx.path(ctx.attr._node)
    nodedir = node.dirname.dirname
    npm = ctx.path(ctx.attr._npm)
    install_path = ctx.path("._npmtemp")
    cache_path = ctx.path("._npmcache")

    modules = []
    for k, v in ctx.attr.deps.items():
        if v:
            modules.append("%s@%s" % (k, v))
        else:
            modules.append(k)

    cmd = [
        node,
        npm,
        "install",
        "--global",
        "--prefix",
        install_path,
        "--cache",
        cache_path,
    ]

    if ctx.attr.registry:
        cmd += ["--registry", ctx.attr.registry]

    cmd += modules

    execute(ctx, cmd)

    cmd = [
        node,
        npm,
        "pack",
        "--parseable",
        "--cache",
        cache_path,
    ]

    if ctx.attr.registry:
        cmd += ["--registry", ctx.attr.registry]

    cmd += modules

    files = execute(ctx, cmd).stdout.split("\n")

    i = 0
    for module in ctx.attr.deps.keys():
        deps_cmd = [
            node,
            "-p",
            "deps=require('%s/lib/node_modules/%s/package.json').dependencies;if(deps){JSON.stringify(Object.keys(deps).map(d=>'//'+d))}else{'[]'}" % (install_path, module)
        ]
        deps = execute(ctx, deps_cmd).stdout
        ctx.file("%s/BUILD" % module, BUILD_FILE.format(
            name = module,
            file = files[i],
            deps = deps,
        ), executable = False)
        ctx.symlink(files[i], "%s/%s" % (module, files[i]))
        i += 1

npm_repository = repository_rule(
    implementation = _npm_repository_impl,
    attrs = {
        "registry": attr.string(),
        "deps": attr.string_dict(mandatory = True),
        "_node": attr.label(
            default = Label("@com_happyco_rules_node_toolchain//:bin/node"),
            single_file = True,
            allow_files = True,
            executable = True,
            cfg = "host",
        ),
        "_npm": attr.label(
            default = Label("@com_happyco_rules_node_toolchain//:bin/npm"),
            single_file = True,
            allow_files = True,
            executable = True,
            cfg = "host",
        ),
    },
)

def _npm_library(ctx):
    deps = depset()
    for d in ctx.attr.deps:
        deps += d.node_library.transitive_deps
    deps += ctx.files.srcs
    return struct(
        files = depset(ctx.files.srcs),
        node_library = struct(
            name = ctx.label.name,
            label = ctx.label,
            transitive_deps = deps,
        ),
    )

npm_library = rule(
    implementation = _npm_library,
    attrs = {
        "srcs": attr.label(
            allow_files = [".tgz"],
        ),
        "deps": attr.label_list(
            providers = ["node_library"],
        ),
        "_node": attr.label(
            default = Label("@com_happyco_rules_node_toolchain//:bin/node"),
            single_file = True,
            allow_files = True,
            executable = True,
            cfg = "host",
        ),
        "_npm": attr.label(
            default = Label("@com_happyco_rules_node_toolchain//:bin/npm"),
            single_file = True,
            allow_files = True,
            executable = True,
            cfg = "host",
        ),
    },
)
