load("//node:internal/node_utils.bzl", "package_rel_path", "make_install_cmd", "get_lib_name")

def node_library_impl(ctx):
    node = ctx.executable._node
    npm = ctx.executable._npm

    srcs = ctx.files.srcs

    lib_name = get_lib_name(ctx)
    staging_path = "./" + lib_name + ".npmfiles"
    modules_path = "%s/%s" % (staging_path, "node_modules")

    cmds = []
    cmds += ["mkdir -p %s" % staging_path]
    cmds += ["mkdir -p %s" % modules_path]

    for src in srcs:
        dst = "%s/%s" % (staging_path, package_rel_path(ctx, src))
        cmds.append("mkdir -p %s && cp -f %s %s" % (dst[:dst.rindex("/")], src.path, dst))

    cmds += make_install_cmd(ctx, modules_path)

    cmds += [" ".join([
        node.path,
        npm.path,
        "--quiet",
        "--offline",
        "--no-update-notifier",
        "--cache ._npmcache",
        "pack",
        staging_path,
        "| xargs -n 1 -I %% mv %% %s" % ctx.outputs.package.path,
    ])]

    # not sure why, but for some reason bazel fails if there are files in .bin
    # this works around it (we don't need .bin for libraries)
    cmds += ["rm -f %s/.bin/*" % modules_path]

    cmds += ["rm -rf ._npmcache"]

    #print("cmds: \n%s" % "\n".join(cmds))

    deps = depset()
    for d in ctx.attr.deps:
        deps += d.node_library.transitive_deps

    ctx.action(
        mnemonic = "NodePack",
        inputs = [node, npm] + srcs + deps.to_list(),
        outputs = [ctx.outputs.package],
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
