load("//node:internal/node_utils.bzl", "package_rel_path", "make_install_cmd", "get_lib_name")

def node_library_impl(ctx):
    node = ctx.executable._node
    npm = ctx.executable._npm

    srcs = ctx.files.srcs
    outs = []

    lib_name = get_lib_name(ctx)
    stage_name = lib_name + ".npmfiles"
    staging_dir = ctx.new_file(stage_name)
    modules_dir = ctx.new_file("%s/node_modules" % stage_name)

    cmds = []
    cmds += ["mkdir -p %s" % staging_dir.path]
    cmds += ["mkdir -p %s" % modules_dir.path]

    for src in srcs:
        dst = ctx.new_file("%s/%s" % (stage_name, package_rel_path(ctx, src)))
        outs += [dst]
        cmds.append("cp -f %s %s" % (src.path, dst.path))

    cmds += make_install_cmd(ctx, modules_dir)


    cmds += [" ".join([
        node.path,
        npm.path,
        "--quiet",
        "--offline",
        "--no-update-notifier",
        "--cache ._npmcache",
        "pack",
        staging_dir.path,
        "| xargs -n 1 -I %% mv %% %s" % ctx.outputs.package.path,
    ])]

    # not sure why, but for some reason bazel fails if there are files in .bin
    # this works around it (we don't need .bin for libraries)
    cmds += ["rm -f %s/.bin/*" % modules_dir.path]

    cmds += ["rm -rf ._npmcache"]

    #print("cmds: \n%s" % "\n".join(cmds))

    deps = depset()
    for d in ctx.attr.deps:
        deps += d.node_library.transitive_deps

    ctx.action(
        mnemonic = "NodePack",
        inputs = [node, npm] + srcs + deps.to_list(),
        outputs = [ctx.outputs.package, staging_dir, modules_dir] + outs,
        command = " && ".join(cmds),
    )

    deps += [ctx.outputs.package]
    return struct(
        files = depset([ctx.outputs.package]),
        node_library = struct(
            name = lib_name,
            label = ctx.label,
            transitive_deps = deps,
        ),
    )

node_library = rule(
    node_library_impl,
    attrs = {
        "srcs": attr.label_list(
            allow_files = True,
        ),
        "deps": attr.label_list(
            providers = ["node_library"],
        ),
        "package_name": attr.string(), # bazel doesn't appear to allow a rule to read data from a file so need to specify this here
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
    outputs = {
        "package": "%{name}.tgz",
    },
)
