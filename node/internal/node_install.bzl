load("//node:internal/node_utils.bzl", "full_path", "package_rel_path", "make_install_cmd")

def _node_install_impl(ctx):
    node = ctx.file._node
    npm = ctx.file._npm

    modules_dir = ctx.new_file(ctx.label.name)
    modules_path = modules_dir.path

    cmds = []
    cmds += ["mkdir -p %s" % modules_path]

    if ctx.files.modules:
        cmds += [
            "cp -aLf %s/* %s" % (full_path(ctx.files.modules[0]), modules_path),
            "mkdir -p %s/.bin" % modules_path,
            "cp -a %s/.bin/* %s/.bin" % (full_path(ctx.files.modules[0]), modules_path),
        ]

    if len(ctx.attr.deps) > 0:
        cmds += make_install_cmd(ctx, modules_path)

    #print("cmds: \n%s" % "\n".join(cmds))

    deps = depset()
    for d in ctx.attr.deps:
        deps += d.node_library.transitive_deps

    ctx.action(
        mnemonic = "NodeInstall",
        inputs = [node, npm] + deps.to_list(),
        outputs = [modules_dir],
        command = " && ".join(cmds),
    )

    return struct(
        files = depset([modules_dir]),
        runfiles = ctx.runfiles(files = [modules_dir], collect_data = True),
    )

node_install = rule(
    _node_install_impl,
    attrs = {
        "modules": attr.label(
            single_file = True,
            allow_files = FileType(["node_modules"]),
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
