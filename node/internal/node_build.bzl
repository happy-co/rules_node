load("//node:internal/node_utils.bzl", "full_path", "package_rel_path", "make_install_cmd")

def _node_build_impl(ctx):
    node = ctx.file._node
    npm = ctx.file._npm

    modules_path = "%s/%s/%s" % (ctx.bin_dir.path, ctx.label.package, "node_modules")

    cmds = []
    cmds += ["mkdir -p %s" % modules_path]

    if ctx.files.modules:
        cmds += [
            "cp -aLf %s/* %s" % (full_path(ctx.files.modules[0]), modules_path),
            "mkdir -p %s/.bin" % modules_path,
            "cp -a %s/.bin/* %s/.bin" % (full_path(ctx.files.modules[0]), modules_path),
        ]

    srcs = ctx.files.srcs
    staged_srcs = []
    outs = depset(ctx.outputs.outs)

    for src in srcs:
        short_path = package_rel_path(ctx, src)
        if short_path.startswith("external/"): # don't map folders for external repos
            short_path = ""
        dst = "%s/%s/%s" % (ctx.bin_dir.path, ctx.label.package, short_path)
        staged_srcs += [dst]
        cmds.append("mkdir -p %s && cp -aLf %s %s" % (dst[:dst.rindex("/")], src.path, dst))

    if len(ctx.attr.deps) > 0:
        cmds += make_install_cmd(ctx, modules_path)

    cmds += ["export HOME=`pwd`"]
    cmds += ["cd %s/%s" % (ctx.bin_dir.path, ctx.label.package)]

    run_cmd = [
        "PATH=$PATH",
        full_path(node),
        full_path(npm),
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
            allow_files = FileType(["node_modules", ".tgz"]),
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
