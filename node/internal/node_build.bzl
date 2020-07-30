load("//node:internal/node_utils.bzl", "node_install", "NodeModule", "ModuleGroup", "package_rel_path", "get_modules")

def _node_build_impl(ctx):
    modules_path = struct(
        path = "%s/%s/node_modules" % (ctx.bin_dir.path, ctx.label.package),
        dirname = "%s/%s" % (ctx.bin_dir.path, ctx.label.package),
    )
    modules = get_modules(ctx.attr.deps)
    inst = node_install(ctx, modules_path, modules)

    node = ctx.file._node
    npm = ctx.file._npm

    cmds = inst.cmds

    for src in ctx.files.srcs:
        short_path = package_rel_path(ctx, src)
        dst = "%s/%s" % (modules_path.dirname, short_path)
        if dst[:dst.rindex("/")] != modules_path.dirname:
            cmds.append("mkdir -p %s" % (dst[:dst.rindex("/")]))
        if src.path != dst:
            cmds.append("cp -aLf %s %s" % (src.path, dst))

    env = []
    for k, v in ctx.attr.env.items():
        env.append("%s='%s'" % (k, v))

    run_cmd = []
    extra_inputs = []
    if env and ctx.info_file and ctx.version_file:
        script_template = ctx.actions.declare_file("env.sh.tmpl")
        script_content = []
        for i in env:
            script_content.append("export %s" % i)
        ctx.actions.write(script_template, "\n".join(script_content))

        script = ctx.actions.declare_file("env.sh")
        ctx.actions.run_shell(
            mnemonic = "NodeBuildExpandEnv",
            inputs = [script_template, ctx.info_file, ctx.version_file, ctx.executable._expand_template, ctx.executable._node],
            outputs = [script],
            command = "%s %s %s %s %s %s" % (
                ctx.executable._node.path,
                ctx.executable._expand_template.path,
                ctx.info_file.path,
                ctx.version_file.path,
                script_template.path,
                script.path,
            ),
        )

        cmds.append("source %s" % script.path)
        extra_inputs.append(script)
    else:
        run_cmd.extend(env)

    cmds.append("export HOME=`pwd`")
    cmds.append("cd %s" % (modules_path.dirname))

    run_cmd.extend([
        "PATH=$PATH",
        "$HOME/%s" % (node.path),
        "$HOME/%s" % (npm.path),
        "run-script",
        ctx.attr.script,
        "--offline",
        "--no-update-notifier",
        "--scripts-prepend-node-path",
    ])

    cmds.append(" ".join(run_cmd))

    deps = depset()
    for d in modules:
        deps += [dd.file for dd in d.deps]

    ctx.actions.run_shell(
        mnemonic = "NodeBuild",
        inputs = [node, npm] + ctx.files.srcs + deps.to_list() + inst.inputs + extra_inputs,
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
        "srcmap": attr.string_dict(),
        "deps": attr.label_list(
            providers = [
                [NodeModule],
                [ModuleGroup],
            ],
        ),
        "env": attr.string_dict(),
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
        "_expand_template": attr.label(
            default=Label("//node/tools:expand_template.js"),
            single_file = True,
            allow_files = True,
            executable = True,
            cfg="host",
        ),
    },
)
