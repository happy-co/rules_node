node_attrs = {
    "node": attr.label(
        default = Label("@com_happyco_rules_node_toolchain//:bin/node"),
        single_file = True,
        allow_files = True,
        executable = True,
        cfg = "host",
    ),
}

def execute(repository_ctx, cmds, path = "", debug = False):
    if path != "":
      cmd = ["export PATH=%s:$PATH" % path, "&&"] + cmds
      cmds = ["/bin/sh", "-c", " ".join(cmd)]
    if debug:
      print("cmd: %s" % " ".join(cmds))
    result = repository_ctx.execute(cmds, quiet=not(debug))
    if result.return_code:
        fail(" ".join(cmds) + "failed: %s" %(result.stderr))
    return result

def package_rel_path(ctx, file):
    rel_path = file.path
    if rel_path.startswith(ctx.genfiles_dir.path):
        rel_path = rel_path[len(ctx.genfiles_dir.path)+1:]
    if rel_path.startswith(ctx.bin_dir.path):
        rel_path = rel_path[len(ctx.bin_dir.path)+1:]
    if len(ctx.label.workspace_root) > 0 and rel_path.startswith(ctx.label.workspace_root):
        rel_path = rel_path[len(ctx.label.workspace_root)+1:]
    if len(ctx.label.package) > 0 and rel_path.startswith(ctx.label.package):
        rel_path = rel_path[len(ctx.label.package)+1:]
    # print("file: %s" % file.path)
    # print("rel_path: %s" % rel_path)
    return rel_path


def get_lib_name(ctx):
    if len(ctx.attr.package_name) > 0:
        return ctx.attr.package_name
    name = ctx.label.name
    parts = ctx.label.package.split("/")
    if (len(parts) == 0) or (name != parts[-1]):
        parts.append(name)
    return "-".join(parts)

# installs the node_library dependencies for the context
#
# if use_package is true, then package.json should already be in modules_dir/..
#  - installation will then load the deps into the cache and then install all deps from package.json
# otherwise - installation loads the deps directly
def make_install_cmd(ctx, modules_path, use_package = True):
    if use_package and not modules_path.endswith("node_modules"):
        fail("modules_path (%s) must end in node_modules" % modules_path)

    node = ctx.executable._node
    npm = ctx.executable._npm

    deps = depset()
    for dep in ctx.attr.deps:
        deps += dep.node_library.transitive_deps

    cmds = []

    cache_path = "._npmcache"

    install_cmd = [
        node.path,
        npm.path,
        "--loglevel error",
        "--offline",
        "--no-update-notifier",
        "--global --prefix",
        "._npmtemp" if use_package else modules_path,
        "--cache",
        cache_path,
        "install",
        "--no-save",
        "--save=false",
        " ".join([f.path for f in deps.to_list()]),
        "> /dev/null",
    ]
    cmds += [" ".join(install_cmd)]

    if use_package:
        cmds += [
            "mkdir -p %s" % modules_path,
            "cp -a ._npmtemp/lib/node_modules/* %s" % (modules_path),
            "mkdir -p %s/.bin" % (modules_path),
            "if [ -d ._npmtemp/bin ]; then for f in ._npmtemp/bin/*; do ln -fs ../$(readlink $f | cut -c20-) %s/.bin/$(basename $f); done; fi" % (modules_path),
        ]

    cmds += ["rm -rf %s" % cache_path]

    # print("install cmds: \n%s" % "\n".join(cmds))

    return cmds
