load("//node:internal/node_utils.bzl", do_node_install = "node_install", "NodeModule")

def _node_install_impl(ctx):
    modules_path = ctx.actions.declare_directory(ctx.label.name)
    inst = do_node_install(ctx, modules_path, [d[NodeModule] for d in ctx.attr.deps])
    ctx.actions.run_shell(
        outputs = [modules_path],
        inputs = inst.inputs,
        mnemonic = "NodeInstall",
        command = " && ".join(inst.cmds),
        progress_message = "Installing node modules",
    )
    return [DefaultInfo(
        files = depset([modules_path]),
        runfiles = ctx.runfiles(files = [modules_path], collect_data = True),
    )]

node_install = rule(
    _node_install_impl,
    attrs = {
        "deps": attr.label_list(
            providers = [NodeModule],
        ),
        "_node": attr.label(
            default = Label("@com_happyco_rules_node_toolchain//:bin/node"),
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
