load("//node:internal/node_utils.bzl", "NodeModule", "node_install", "package_rel_path")
load("//node:internal/node_library.bzl", "node_library")

_ts_filetype = [".ts", ".tsx"]

def _ts_compile_impl(ctx):
    node = ctx.file._node
    npm = ctx.file._npm
    tsc = ctx.file._tsc

    modules_path = ctx.actions.declare_directory("node_modules")
    inst = node_install(ctx, modules_path, [d[NodeModule] for d in ctx.attr.deps])

    cmds = inst.cmds

    srcs = ctx.files.srcs
    staged_srcs = []
    outs = depset()

    for src in srcs:
        short_path = package_rel_path(ctx, src)
        dst = "%s/%s/%s" % (ctx.bin_dir.path, ctx.label.package, short_path)
        if short_path.endswith(".ts"):
            outs += [
                ctx.new_file(short_path[:-3] + ".d.ts"),
                ctx.new_file(short_path[:-3] + ".js"),
            ]
        else:
            outs += [
                ctx.new_file(short_path[:-4] + ".d.ts"),
                ctx.new_file(short_path[:-4] + ".jsx"),
            ]
        staged_srcs += [dst]
        cmds.append("mkdir -p %s && cp -f %s %s" % (dst[:dst.rindex("/")], src.path, dst))

    tsc_cmd = [
        node.path,
        tsc.path,
        "--declaration",
        "--sourceMap",
        "--moduleResolution node",
        "--target",
        ctx.attr.target,
        "--strict" if ctx.attr.strict else "",
        "--noImplicitAny" if ctx.attr.noImplicitAny else "",
        "--removeComments" if ctx.attr.removeComments else "",
        "--preserveConstEnums" if ctx.attr.preserveConstEnums else "",
        "--strictNullChecks" if ctx.attr.strictNullChecks else "",
    ] + [f for f in staged_srcs]

    cmds += [" ".join(tsc_cmd)]

    #print("cmds: \n%s" % "\n".join(cmds))

    deps = depset()
    for d in ctx.attr.deps:
        deps += [dd.file for dd in d[NodeModule].deps]

    ctx.actions.run_shell(
        mnemonic = "Typescript",
        inputs = [node, npm, tsc] + srcs + deps.to_list() + inst.inputs,
        outputs = outs.to_list() + [modules_path],
        command = " && ".join(cmds),
        env = {
            "NODE_PATH": tsc.dirname + "/..",
        },
    )

    return [
        DefaultInfo(
            files = outs,
            runfiles = ctx.runfiles([], outs, collect_data = True),
        ),
    ]

ts_compile = rule(
    _ts_compile_impl,
    attrs = {
        "srcs": attr.label_list(
            mandatory = True,
            allow_files = _ts_filetype,
        ),
        "deps": attr.label_list(
            providers = [NodeModule],
        ),
        "target": attr.string(
            default = "ES3",
            values = ["ES3", "ES5", "ES6", "ES2015", "ES2016", "ES2017", "ESNext"],
        ),
        "strict": attr.bool(),
        "noImplicitAny": attr.bool(),
        "removeComments": attr.bool(),
        "preserveConstEnums": attr.bool(),
        "strictNullChecks": attr.bool(),
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
        "_link_bins": attr.label(
            default = Label("//node/tools:link_bins.js"),
            single_file = True,
            allow_files = True,
            executable = True,
            cfg = "host",
        ),
    },
)

def ts_library(name, ts_srcs, node_srcs, deps = [], package_name = None, **kwargs):
    ts_compile(name = name + "_ts", srcs = ts_srcs, deps = deps, **kwargs)
    node_library(name = name, srcs = node_srcs + [name + "_ts"], deps = deps, package_name = package_name)
