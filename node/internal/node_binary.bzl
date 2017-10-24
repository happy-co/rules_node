BASH_TEMPLATE = """#!/usr/bin/env bash
set -e

# Run it but wrap all calls to paths in a call to find. The call to find will
# search recursively through the filesystem to find the appropriate runfiles
# directory if that is necessary.
ROOT=$(find -L $(dirname "$0") | grep -m 1 "{script_path}" | sed 's|{script_path}$||')

# Resolve to 'this' node instance if other scripts
# have '/usr/bin/env node' shebangs
export HOME=${{HOME:-$PWD}}
export PATH=$ROOT/{node_bin_path}:$PATH
export NODE_PATH=$ROOT/{node_path}

exec "$ROOT/{script_path}" $@
"""

load("//node:internal/node_utils.bzl", "node_install", "NodeModule")

def node_binary_impl(ctx):
    modules_path = ctx.actions.declare_directory("node_modules", sibling = ctx.outputs.executable)
    inst = node_install(ctx, modules_path, [d[NodeModule] for d in ctx.attr.deps])
    ctx.actions.run_shell(
        outputs = [modules_path],
        inputs = inst.inputs,
        mnemonic = "NodeInstall",
        command = " && ".join(inst.cmds),
        progress_message = "Installing node modules",
    )
    node = ctx.file._node
    ctx.file_action(
        output = ctx.outputs.executable,
        executable = True,
        content = BASH_TEMPLATE.format(
            script_path = "/".join([modules_path.short_path, ".bin", ctx.attr.script]),
            node_bin_path = node.dirname,
            node_path = modules_path.short_path,
        ),
    )
    return [
        DefaultInfo(
            runfiles = ctx.runfiles(
                files = [node, modules_path],
                collect_data = True,
            )
        )
    ]

node_binary = rule(
    node_binary_impl,
    attrs = {
        "script": attr.string(mandatory = True),
        "deps": attr.label_list(
            mandatory = True,
            allow_empty = False,
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
    executable = True,
)
