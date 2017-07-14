_ts_filetype = FileType([".ts", ".tsx"])

load("//node:internal/node_utils.bzl", "package_rel_path", "make_install_cmd")

def _ts_compile_impl(ctx):
    node = ctx.file._node
    npm = ctx.file._npm
    tsc = ctx.file._tsc

    modules_dir = ctx.new_file("node_modules")

    cmds = []
    cmds += ["mkdir -p %s" % modules_dir.path]

    srcs = ctx.files.srcs
    staged_srcs = []
    outs = depset()

    for src in srcs:
        short_path = package_rel_path(ctx, src)
        dst = ctx.new_file(short_path)
        if short_path.endswith(".ts"):
            outs += [ctx.new_file(short_path[:-3]+".d.ts"),
                     ctx.new_file(short_path[:-3]+".js")]
        else:
            outs += [ctx.new_file(short_path[:-3]+".d.ts"),
                     ctx.new_file(short_path[:-3]+".jsx")]
        staged_srcs += [dst]
        cmds.append("cp -f %s %s" % (src.path, dst.path))

    cmds += make_install_cmd(ctx, modules_dir)

    ctx.action(
        mnemonic = "TypescriptPrepare",
        inputs = [node, npm] + ctx.files.deps + srcs,
        outputs = [modules_dir] + staged_srcs,
        command = " && ".join(cmds),
    )

    tsc_cmd = [
        node.path,
        tsc.path,
        "--declaration",
        "--sourceMap",
        "--target", ctx.attr.target,
        "--strict" if ctx.attr.strict else "",
    ] + [f.path for f in staged_srcs]

    ctx.action(
        mnemonic = "TypescriptCompile",
        inputs = [node, tsc, modules_dir] + staged_srcs,
        outputs = outs.to_list(),
        command = " ".join(tsc_cmd),
        env = {
            "NODE_PATH": tsc.dirname + "/..",
        },
    )

    deps = depset()
    for d in ctx.attr.deps:
        deps += d.node_library.transitive_deps
    return struct(
        files = outs,
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
