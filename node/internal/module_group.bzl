load("//node:internal/node_utils.bzl", "NodeModule", "ModuleGroup", "demangle_package_name")

def _module_group_impl(ctx):
    modules = depset()
    for s in ctx.attr.srcs:
        if ModuleGroup in s:
            modules += s[ModuleGroup].modules
        else:
            modules += [s[NodeModule]]
    return [ModuleGroup(modules = modules)]

module_group = rule(
    _module_group_impl,
    attrs = {
        "srcs": attr.label_list(
            mandatory = True,
            providers = [
                [NodeModule],
                [ModuleGroup],
            ],
        ),
    },
)

def _sealed_module_group_impl(ctx):
    modules = depset()
    for s in ctx.attr.srcs:
        if len(s.files) != 1: fail("sealed module srcs should be directories, %s contains %s" % (s.label, s.files))
        modules += [NodeModule(
            name = demangle_package_name(s.label.name.split("/")[-1]),
            label = s.label,
            file = s.files.to_list()[0],
            deps = depset(),
            wrapped_deps = depset(),
        )]
    return [ModuleGroup(modules = modules)]

sealed_module_group = rule(
    _sealed_module_group_impl,
    attrs = {
        "srcs": attr.label_list(
            mandatory = True,
            allow_files = True,
        ),
    },
)
