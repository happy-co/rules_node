BASH_TEMPLATE = """#!/usr/bin/env bash
set -e

# Run it but wrap all calls to paths in a call to find. The call to find will
# search recursively through the filesystem to find the appropriate runfiles
# directory if that is necessary.
ROOT=$(find $(dirname "$0") | grep -m 1 "{script_path}" | sed 's|{script_path}$||')

# Resolve to 'this' node instance if other scripts
# have '/usr/bin/env node' shebangs
export HOME=${{HOME:-$PWD}}
export PATH=$ROOT/{node_bin_path}:$PATH
export NODE_PATH=$ROOT/{node_path}

exec "$ROOT/{script_path}" $@
"""

load("//node:internal/node_utils.bzl", "make_install_cmd")

def node_binary_impl(ctx):
    node = ctx.file._node
    npm = ctx.file._npm

    modules_dir = ctx.new_file(ctx.outputs.executable, "node")

    cmds = []
    cmds += ["mkdir -p %s" % modules_dir.path]

    cmds += make_install_cmd(ctx, modules_dir.path, use_package = False)

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

    ctx.file_action(
        output = ctx.outputs.executable,
        executable = True,
        content = BASH_TEMPLATE.format(
            script_path = "/".join([modules_dir.short_path, "bin", ctx.attr.script]),
            node_bin_path = node.dirname,
            node_path = modules_dir.short_path,
        ),
    )

    runfiles = [node, modules_dir]

    return struct(
        runfiles = ctx.runfiles(
            files = runfiles,
            collect_data = True,
        )
    )

node_binary = rule(
    node_binary_impl,
    attrs = {
        "script": attr.string(mandatory = True),
        "deps": attr.label_list(
            mandatory = True,
            allow_empty = False,
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
    executable = True,
)
