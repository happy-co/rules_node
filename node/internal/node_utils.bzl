node_attrs = {
    "node": attr.label(
        default = Label("@com_happyco_rules_node_toolchain//:bin/node"),
        single_file = True,
        allow_files = True,
        executable = True,
        cfg = "host",
    ),
}

def execute(repository_ctx, cmds, debug = False):
    if debug:
      print("cmd: %s" % " ".join(cmds))
    result = repository_ctx.execute(cmds, quiet=not(debug))
    if result.return_code:
        fail(" ".join(cmds) + "failed: %s" %(result.stderr))
    return result

def _root_path(root):
    #print("root: %s" % root)
    return str(root).split("[")[0]

def _file_path(file):
    #print("file: %s" % file)
    return str(file).split("]")[-1]

def full_path(file_or_root):
    full_path = file_or_root.path
    if hasattr(file_or_root, "root"):
        full_path = "%s/%s" % (_root_path(file_or_root.root), _file_path(file_or_root))
        #print("%s => %s" % (str(file_or_root), full_path))
    else:
        full_path = _root_path(file_or_root)
    return full_path

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
def make_install_cmd(ctx, modules_dir, cache_path, use_package = True):
    if use_package and modules_dir.basename != "node_modules":
        fail("modules_dir must end in node_modules")

    node = ctx.executable._node
    npm = ctx.executable._npm

    deps = depset()
    for dep in ctx.attr.deps:
        deps += dep.node_library.transitive_deps

    cmds = []
    if use_package:
        cmds += ["cd %s/.." % modules_dir.path]

    install_cmd = [
        full_path(node),
        full_path(npm),
        "--loglevel error",
        "--offline",
        "--no-update-notifier",
        "--global --prefix %s" % modules_dir.path if not use_package else "",
        "--cache",
        cache_path,
        "install",
        "--no-save",
        "--save=false",
        " ".join([full_path(f) for f in deps.to_list()]),
        "> /dev/null",
    ]
    cmds += [" ".join(install_cmd)]

    if use_package:
        check_cmd = [
            full_path(node),
            full_path(npm),
            "--offline",
            "--no-update-notifier",
            "--cache",
            cache_path,
            "ls",
            "> /dev/null"
        ]
        cmds += [" ".join(check_cmd)]
        cmds += ["cd - > /dev/null"]

    #print("install cmds: \n%s" % "\n".join(cmds))

    return cmds
