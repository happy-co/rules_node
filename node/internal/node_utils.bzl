#
# Repository utils
#

BUILD_FILE = """package(default_visibility = ["//visibility:public"])
load("@com_happyco_rules_node//node:rules.bzl", "node_library")

node_library(
    name = "node_module",
    package_name = "{package_name}",
    srcs = glob(include = ["**"], exclude = ["node_modules/**", "BUILD.bazel"]),
    deps = {deps},
    indeps = {indeps},
    wrapped_deps = {wrapped_deps},
)
"""

def init_module(repository_ctx, module):
    targets = [struct(module = module, path = module.basename)]
    wrapped_paths = execute(repository_ctx, [
        "/bin/sh", "-c",
        "(find %s/node_modules -type d | grep '^%s\(/node_modules/[^/]\{1,\}\)\{1,\}$') 2>/dev/null || true" % (module, module),
    ]).stdout.split("\n")
    repo_prefix_len = len(str(repository_ctx.path(".")))
    for w in [repository_ctx.path(w[repo_prefix_len+1:]) for w in wrapped_paths if w and not w.endswith(".bin")]:
        targets.append(struct(module = w, path = str(w)[repo_prefix_len+14:]))
    for t in targets:
        deps_cmd = [
            repository_ctx.path(repository_ctx.attr._node),
            repository_ctx.path(repository_ctx.attr._deps),
            t.module,
        ] + repository_ctx.attr.indeps.keys()
        deps = execute(repository_ctx, deps_cmd).stdout.strip()
        indeps = ["//%s:node_module" % (i) for i in repository_ctx.attr.indeps.get(t.module.basename, [])]

        wrapped_deps = []
        wrapped_path = t.module.get_child("node_modules")
        if wrapped_path.exists:
            for sub_module in wrapped_path.readdir():
                if sub_module.basename.startswith("."): continue
                pkg_path = "%s/node_modules/%s" % (t.path, sub_module.basename)
                if sub_module.basename in repository_ctx.attr.indeps:
                    wrapped_deps.append("//%s:node_indep" % (pkg_path))
                else:
                    wrapped_deps.append("//%s:node_module" % (pkg_path))

        repository_ctx.file(
            "%s/BUILD.bazel" % t.module,
            BUILD_FILE.format(
                package_name = t.module.basename,
                deps = deps,
                indeps = str(indeps),
                wrapped_deps = str(wrapped_deps),
            ), executable = False
        )

    for t in targets:
        # only move top-level modules
        if str(t.module).count("node_modules") == 1:
            execute(repository_ctx, ["mv", t.module, "."])

def execute(repository_ctx, cmds, path = "", debug = False):
    if path:
      cmd = ["export PATH=%s:$PATH" % path, "&&"] + cmds
      cmds = ["/bin/sh", "-c", " ".join(cmd)]
    if debug:
      print("cmd: %s" % " ".join(cmds))
    result = repository_ctx.execute(cmds, quiet=not(debug))
    if result.return_code:
        fail(" ".join(cmds) + "failed: %s" %(result.stderr))
    return result

#
# Rule utils
#

NodeModule = provider(fields = ["name", "label", "file", "deps", "wrapped_deps"])
ModuleGroup = provider(fields = ["modules"])

def merge_deps(deps):
    inner_deps = []
    for i in range(len(deps)):
        d = deps[i]
        d_wrapped = list(d.wrapped_deps)
        for dd in d.deps:
            add = True
            for e in deps:
                if e.label == dd.label:
                    # skip existing
                    add = False
                    break
                if e.name == dd.name:
                    # conflicted name & version
                    d_wrapped += [dd]
                    add = False
                    break
            for e in inner_deps:
                if e.label == dd.label:
                    # skip existing
                    add = False
                    break
                if e.name == dd.name:
                    # conflicted name & version
                    d_wrapped += [dd]
                    add = False
                    break
            if add: inner_deps += [dd]
        deps[i] = NodeModule(
            name = d.name,
            label = d.label,
            file = d.file,
            deps = [],
            wrapped_deps = d_wrapped,
        )
    return deps + inner_deps

def node_install(ctx, install_path, modules):
    inputs = depset()
    cmds = ["mkdir -p %s" % (install_path.path)]
    for m in merge_deps(modules):
        #print("installing:", m.label)
        inputs += [m.file]
        cmds += [
            "mkdir -p %s/%s" % (install_path.path, m.name),
            "tar -xzf %s -C %s/%s --strip-components 1" % (m.file.path, install_path.path, m.name),
        ]
        for w in m.wrapped_deps:
            inputs += [w.file]
            cmds += [
                "mkdir -p %s/%s/node_modules/%s" % (install_path.path, m.name, w.name),
                "tar -xzf %s -C %s/%s/node_modules/%s --strip-components 1" % (w.file.path, install_path.path, m.name, w.name),
            ]
            for w2 in w.wrapped_deps:
                inputs += [w2.file]
                cmds += [
                    "mkdir -p %s/%s/node_modules/%s/node_modules/%s" % (install_path.path, m.name, w.name, w2.name),
                    "tar -xzf %s -C %s/%s/node_modules/%s/node_modules/%s --strip-components 1" % (w2.file.path, install_path.path, m.name, w.name, w2.name),
                ]
                for w3 in w2.wrapped_deps:
                    inputs += [w3.file]
                    cmds += [
                        "mkdir -p %s/%s/node_modules/%s/node_modules/%s/node_modules/%s" % (install_path.path, m.name, w.name, w2.name, w3.name),
                        "tar -xzf %s -C %s/%s/node_modules/%s/node_modules/%s/node_modules/%s --strip-components 1" % (w3.file.path, install_path.path, m.name, w.name, w2.name, w3.name),
                    ]
                    if w2.wrapped_deps: fail("nested wrapped dependencies not supported deeper than 3 levels (in %s)" % w3.label)
    node = ctx.executable._node
    link_bins = ctx.executable._link_bins
    inputs += [node, link_bins]
    cmds += ["%s %s %s" % (node.path, link_bins.path, install_path.path)]
    #print(cmds)
    ctx.actions.run_shell(
        outputs = [install_path],
        inputs = inputs,
        mnemonic = "NodeInstall",
        command = " && ".join(cmds),
        progress_message = "Installing node modules",
    )

def get_modules(deps):
    modules = depset()
    for d in deps:
        if NodeModule in d:
            modules += [d[NodeModule]]
        else:
            modules += d[ModuleGroup].modules
    return modules.to_list()

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
