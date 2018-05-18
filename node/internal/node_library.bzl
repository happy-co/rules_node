load("//node:internal/node_utils.bzl", "merge_deps", "NodeModule", "ModuleGroup", "get_modules")
load("//node:internal/module_group.bzl", "module_group")
load("@bazel_tools//tools/build_defs/pkg:pkg.bzl", "pkg_tar")

def _node_module_impl(ctx):
    merged = merge_deps(get_modules(ctx.attr.deps))
    return [
        DefaultInfo(
            files = depset(ctx.files.srcs),
        ),
        NodeModule(
            name = ctx.attr.package_name if len(ctx.attr.package_name) > 0 else ctx.label.name,
            label = ctx.label,
            file = ctx.file.srcs,
            deps = merged,
            wrapped_deps = get_modules(ctx.attr.wrapped_deps),
        )
    ]

node_module = rule(
    _node_module_impl,
    attrs = {
        "package_name": attr.string(),  # bazel doesn't appear to allow a rule to read data from a file so need to specify this here
        "srcs": attr.label(
            allow_files = [".tar.gz"],
            mandatory = True,
            single_file = True,
        ),
        "deps": attr.label_list(
            providers = [
                [NodeModule],
                [ModuleGroup],
            ],
        ),
        "wrapped_deps": attr.label_list(
            providers = [
                [NodeModule],
                [ModuleGroup],
            ],
        ),
    },
)

def node_library(name, srcs, package_name = "", strip_prefix = "", deps = [], indeps = [], wrapped_deps = [], visibility = None):
    if package_name == "":
        package_name = name

    srcs_by_pkg = {}
    for s in srcs:
        pkg_name = Label("//%s" % native.package_name()).relative(s).package
        ss = srcs_by_pkg.get(pkg_name, [])
        ss.append(s)
        srcs_by_pkg[pkg_name] = ss
    for p in srcs_by_pkg:
        if strip_prefix == "":
            strip_prefix = "." if p == native.package_name() else "/%s" % p
        else:
            strip_prefix = "./%s" % strip_prefix if p == native.package_name() else "/%s/%s" % (p, strip_prefix)

        pkg_tar(
            name = "%s-%s" % (name, p.replace("/", "_")),
            strip_prefix = strip_prefix,
            package_dir = "/",
            srcs = srcs_by_pkg[p],
        )
    pkg_tar(
        name = "%s-package" % (name),
        extension = "tar.gz",
        deps = [":%s-%s" % (name, p.replace("/", "_")) for p in srcs_by_pkg.keys()],
    )
    if indeps:
        stripped_deps = [d for d in deps if not d in indeps]
        # print("\n%s\n%s\n%s" % (package_name, stripped_deps, indeps))
        node_module(
            name = "node_indep",
            package_name = package_name,
            srcs = ":%s-package" % (name),
            deps = stripped_deps,
            wrapped_deps = wrapped_deps,
        )
        module_group(
            name = name,
            srcs = [":node_indep"] + indeps,
        )
    else:
        node_module(
            name = name,
            package_name = package_name,
            srcs = ":%s-package" % (name),
            deps = deps,
            wrapped_deps = wrapped_deps,
            visibility = visibility,
        )
