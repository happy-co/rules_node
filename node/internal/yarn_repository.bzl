load("//node:internal/node_utils.bzl", "execute")
load("//node:internal/npm_repository.bzl", "BUILD_FILE", "npm_library")

def _yarn_repository_impl(ctx):
    node = ctx.path(ctx.attr._node)
    nodedir = node.dirname.dirname
    yarn = ctx.path(ctx.attr._yarn)

    cmd = [
        "cp",
        ctx.path(ctx.attr.package),
        ctx.path("."),
    ]
    execute(ctx, cmd)

    cmd = [
        "cp",
        ctx.path(ctx.attr.lockfile),
        ctx.path("."),
    ]
    execute(ctx, cmd)

    cmd = [
        node,
        yarn,
        "install",
        "--pure-lockfile",
        "--non-interactive",
        "--cache-folder",
        ctx.path("._yarncache"),
    ]

    if ctx.attr.registry:
        cmd += ["--registry", ctx.attr.registry]

    execute(ctx, cmd)

    modules = [f.basename for f in ctx.path("node_modules").readdir() if not f.basename.startswith(".")]

    for module in modules:
        deps_cmd = [
            node,
            "-p",
            "deps=require('%s/node_modules/%s/package.json').dependencies;if(deps){JSON.stringify(Object.keys(deps).map(d=>'//'+d))}else{'[]'}" % (ctx.path("."), module)
        ]
        deps = execute(ctx, deps_cmd).stdout
        ctx.file("%s/BUILD" % module, BUILD_FILE.format(
            name = module,
            file = "%s.tgz" % module,
            deps = deps,
        ), executable = False)
        cmd = [
            "cd %s/node_modules/%s" % (ctx.path("."), module),
            "&&",
            node,
            yarn,
            "pack",
            "--non-interactive",
            "--cache-folder",
            ctx.path("._yarncache"),
            "--filename",
            ctx.path("%s/%s.tgz" % (module, module)),
            "&&",
            "cd -",
        ]
        execute(ctx, ["/bin/sh", "-c", " ".join(cmd)])

    ctx.file("BUILD", "exports_files([%s])\n" % (",".join(["\"node_modules/%s\"" % module for module in modules])), executable = False)

yarn_repository = repository_rule(
    implementation = _yarn_repository_impl,
    attrs = {
        "registry": attr.string(),
        "package": attr.label(
            mandatory = True,
            single_file = True,
            allow_files = ["package.json"],
        ),
        "lockfile": attr.label(
            mandatory = True,
            single_file = True,
            allow_files = ["yarn.lock"],
        ),
        "_node": attr.label(
            default = Label("@com_happyco_rules_node_toolchain//:bin/node"),
            single_file = True,
            allow_files = True,
            executable = True,
            cfg = "host",
        ),
        "_yarn": attr.label(
            default = Label("@com_happyco_rules_node_toolchain//:bin/yarn"),
            single_file = True,
            allow_files = True,
            executable = True,
            cfg = "host",
        ),
    },
)
