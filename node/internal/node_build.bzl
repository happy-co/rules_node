load("//node:internal/node_utils.bzl", "node_install", "NodeModule", "ModuleGroup", "package_rel_path", "get_modules")

def _node_build_impl(ctx):
    modules_path = ctx.actions.declare_directory("node_modules")
    modules = get_modules(ctx.attr.deps)
    node_install(ctx, modules_path, modules)

    node = ctx.file._node
    npm = ctx.file._npm

    cmds = []

    for src in ctx.files.srcs:
        short_path = package_rel_path(ctx, src)
        if short_path.startswith("external/"): # don't map folders for external repos
            short_path = ""
        dst = "%s/%s" % (modules_path.dirname, short_path)
        if dst[:dst.rindex("/")] != modules_path.dirname:
            cmds.append("mkdir -p %s" % (dst[:dst.rindex("/")]))
        cmds.append("cp -aLf %s %s" % (src.path, dst))

    cmds.append("export HOME=`pwd`")
    cmds.append("cd %s" % (modules_path.dirname))

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

    cmds.append(" ".join(run_cmd))

    #print("cmds: \n%s" % "\n".join(cmds))

    deps = depset([modules_path])
    for d in modules:
        deps += [dd.file for dd in d.deps]

    ctx.actions.run_shell(
        mnemonic = "NodeBuild",
        inputs = [node, npm] + ctx.files.srcs + deps.to_list(),
        outputs = ctx.outputs.outs,
        command = " && ".join(cmds),
    )

    outs = depset(ctx.outputs.outs)
    return [
        DefaultInfo(
            files = outs,
            runfiles = ctx.runfiles([], outs, collect_data = True),
        )
    ]

node_build = rule(
    _node_build_impl,
    attrs = {
        "srcs": attr.label_list(
            mandatory = True,
            allow_files = True,
        ),
        "deps": attr.label_list(
            providers = [[NodeModule], [ModuleGroup]],
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
        "_link_bins": attr.label(
            default = Label("//node/tools:link_bins.js"),
            single_file = True,
            allow_files = True,
            executable = True,
            cfg = "host",
        ),
    },
)
