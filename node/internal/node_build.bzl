load("//node:internal/node_utils.bzl", "package_rel_path", "make_install_cmd")

def _node_build_impl(ctx):
    node = ctx.file._node
    npm = ctx.file._npm

    modules_path = "%s/%s/%s" % (ctx.bin_dir.path, ctx.label.package, "node_modules")

    srcs = []

    cmds = []
    cmds += ["mkdir -p %s" % modules_path]

    if ctx.file.modules:
        cmds += [
            "cp -aLf %s/* %s" % (ctx.file.modules.path, modules_path),
            "mkdir -p %s/.bin" % modules_path,
            "cp -a %s/.bin/* %s/.bin" % (ctx.file.modules.path, modules_path),
        ]
        srcs += [ctx.file.modules]

    staged_srcs = []
    outs = depset(ctx.outputs.outs)

    for src in ctx.files.srcs:
        short_path = package_rel_path(ctx, src)
        if short_path.startswith("external/"): # don't map folders for external repos
            short_path = ""
        dst = "%s/%s/%s" % (ctx.bin_dir.path, ctx.label.package, short_path)
        staged_srcs += [dst]
        cmds.append("mkdir -p %s && cp -aLf %s %s" % (dst[:dst.rindex("/")], src.path, dst))

    srcs += ctx.files.srcs

    if len(ctx.attr.deps) > 0:
        cmds += make_install_cmd(ctx, modules_path)

    cmds += ["export HOME=`pwd`"]
    cmds += ["cd %s/%s" % (ctx.bin_dir.path, ctx.label.package)]

    run_cmd = [
        "PATH=$PATH",
        "$HOME/%s" % (node.path),
        "$HOME/%s" % (npm.path),
        "run-script",
        ctx.attr.script,
        "--offline",
        "--no-update-notifier",
        "--scripts-prepend-node-path",
    ]

    cmds += [" ".join(run_cmd)]

    #print("cmds: \n%s" % "\n".join(cmds))

    deps = depset()
    for d in ctx.attr.deps:
        deps += d.node_library.transitive_deps

    ctx.action(
        mnemonic = "NodeBuild",
        inputs = [node, npm] + srcs + deps.to_list(),
        outputs = outs.to_list(),
        command = " && ".join(cmds),
    )

    return struct(
        files = outs,
        runfiles = ctx.runfiles([], outs, collect_data = True),
    )

node_build = rule(
    _node_build_impl,
    attrs = {
        "srcs": attr.label_list(
            mandatory = True,
            allow_files = True,
        ),
        "modules": attr.label(
            single_file = True,
            allow_files = FileType(["node_modules"]),
        ),
        "deps": attr.label_list(
            providers = ["node_library"],
        ),
        "script": attr.string(default = "build"),
        "outs": attr.output_list(),
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
