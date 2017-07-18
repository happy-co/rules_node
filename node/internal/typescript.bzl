_ts_filetype = FileType([".ts", ".tsx"])

load("//node:internal/node_utils.bzl", "package_rel_path", "make_install_cmd")

def _ts_compile_impl(ctx):
    node = ctx.file._node
    npm = ctx.file._npm
    tsc = ctx.file._tsc

    modules_path = "%s/%s/%s" % (ctx.bin_dir.path, ctx.label.package, "node_modules")

    cmds = []
    cmds += ["mkdir -p %s" % modules_path]

    srcs = ctx.files.srcs
    staged_srcs = []
    outs = depset()

    for src in srcs:
        short_path = package_rel_path(ctx, src)
        dst = "%s/%s/%s" % (ctx.bin_dir.path, ctx.label.package, short_path)
        if short_path.endswith(".ts"):
            outs += [ctx.new_file(short_path[:-3]+".d.ts"),
                     ctx.new_file(short_path[:-3]+".js")]
        else:
            outs += [ctx.new_file(short_path[:-4]+".d.ts"),
                     ctx.new_file(short_path[:-4]+".jsx")]
        staged_srcs += [dst]
        cmds.append("mkdir -p %s && cp -f %s %s" % (dst[:dst.rindex("/")], src.path, dst))

    cmds += make_install_cmd(ctx, modules_path)

    tsc_cmd = [
        node.path,
        tsc.path,
        "--declaration",
        "--sourceMap",
        "--target", ctx.attr.target,
        "--strict" if ctx.attr.strict else "",
    ] + [f for f in staged_srcs]

    cmds += [" ".join(tsc_cmd)]

    #print("cmds: \n%s" % "\n".join(cmds))

    deps = depset()
    for d in ctx.attr.deps:
        deps += d.node_library.transitive_deps

    ctx.action(
        mnemonic = "Typescript",
        inputs = [node, tsc] + srcs + deps.to_list(),
        outputs = outs.to_list(),
        command = " && ".join(cmds),
        env = {
            "NODE_PATH": tsc.dirname + "/..",
        },
    )

    return struct(
        files = outs,
        runfiles = ctx.runfiles([], outs, collect_data = True),
        node_library = struct(transitive_deps = deps)
    )

ts_compile = rule(
    _ts_compile_impl,
    attrs = {
        "srcs": attr.label_list(
            mandatory = True,
            allow_files = _ts_filetype,
        ),
        "deps": attr.label_list(
            providers = ["node_library"],
        ),
        "target": attr.string(
            default = "ES3",
            values = ["ES3", "ES5", "ES6", "ES2015", "ES2016", "ES2017", "ESNext"]
        ),
        "strict": attr.bool(),
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
        "_tsc": attr.label(
            default = Label("@com_happyco_rules_node_toolchain//:bin/tsc"),
            single_file = True,
            allow_files = True,
            cfg = "host",
        ),
    },
)

load("//node:internal/node_library.bzl", "node_library")

def ts_library(name, ts_srcs, node_srcs, deps = [], package_name = None, **kwargs):
    ts_compile(name = name + "_ts", srcs = ts_srcs, deps = deps, **kwargs)
    node_library(name = name, srcs = node_srcs + [name + "_ts"], deps = deps, package_name = package_name)
