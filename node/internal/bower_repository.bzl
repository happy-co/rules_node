load("//node:internal/node_utils.bzl", "execute")

def _bower_repository_impl(ctx):
    node = ctx.path(ctx.attr._node)
    nodedir = node.dirname.dirname
    bower = ctx.path(ctx.attr._bower)

    cmd = [
        "cp",
        ctx.path(ctx.attr.manifest),
        ctx.path("."),
    ]
    execute(ctx, cmd)

    cmd = [
        node,
        bower,
        "install",
        "--config.interactive=false",
    ]

    if ctx.attr.registry:
        cmd += ["--config.registry='%s'" % ctx.attr.registry]

    execute(ctx, cmd)

    ctx.file("BUILD", "exports_files([\"bower_components\"])\n", executable = False)

bower_repository = repository_rule(
    implementation = _bower_repository_impl,
    attrs = {
        "registry": attr.string(),
        "manifest": attr.label(
            mandatory = True,
            single_file = True,
            allow_files = ["bower.json"],
        ),
        "_node": attr.label(
            default = Label("@com_happyco_rules_node_toolchain//:bin/node"),
            single_file = True,
            allow_files = True,
            executable = True,
            cfg = "host",
        ),
        "_bower": attr.label(
            default = Label("@com_happyco_rules_node_toolchain//:bin/bower"),
            single_file = True,
            allow_files = True,
            executable = True,
            cfg = "host",
        ),
    },
)
