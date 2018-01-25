load("//node:internal/node_utils.bzl", "execute", "init_module", "mangle_package_name")

def _npm_repository_impl(ctx):
    node = ctx.path(ctx.attr._node)
    nodedir = node.dirname.dirname
    npm = ctx.path(ctx.attr._npm)
    install_path = ctx.path("._npmtemp")
    cache_path = ctx.path("._npmcache")

    modules = []
    for k, v in ctx.attr.deps.items():
        if v:
            modules.append("%s@%s" % (k, v))
        else:
            modules.append(k)

    cmd = [
        node,
        npm,
        "install",
        "--global",
        "--prefix",
        install_path,
        "--cache",
        cache_path,
    ]

    if ctx.attr.registry:
        cmd += ["--registry", ctx.attr.registry]

    cmd += modules

    execute(ctx, cmd)

    modules_path = install_path.get_child("lib").get_child("node_modules")
    execute(ctx, ["find", modules_path, "-iname", "build", "-type", "f", "-exec", "mv", "{}", "{}.js", ";"])
    modules = []

    # Rename and move scoped modules with invalid bazel labels
    for module in modules_path.readdir():
      if module.basename.startswith("@"):
        for scoped_module in module.readdir():
          execute(ctx, ["mv", scoped_module, "%s/%s" % (modules_path, mangle_package_name(module.basename, scoped_module.basename))])


    for module in modules_path.readdir():
        if module.basename.startswith("."): continue
        # scoped modules just contain other modules so don't include them
        if module.basename.startswith("@"): continue

        modules.append("//%s:node_modules" % (module.basename))
        init_module(ctx, module)

    execute(ctx, ["rm", "-rf", install_path, cache_path])
    ctx.file(
        "BUILD",
        """package(default_visibility = ["//visibility:public"])
load("@com_happyco_rules_node//node:rules.bzl", "module_group")

module_group(name = "node_modules", srcs = %s)
""" % (str(modules)),
        executable = False,
    )

npm_repository = repository_rule(
    implementation = _npm_repository_impl,
    attrs = {
        "registry": attr.string(),
        "deps": attr.string_dict(mandatory = True),
        "indeps": attr.string_list_dict(),
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
        "_deps": attr.label(
            default = Label("//node/tools:deps.js"),
            single_file = True,
            allow_files = True,
            executable = True,
            cfg = "host",
        ),
    },
)
