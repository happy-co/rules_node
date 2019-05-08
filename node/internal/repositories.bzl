load("//node:internal/node_utils.bzl", "execute")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

NODE_TOOLCHAIN_BUILD_FILE = """
package(default_visibility = [ "//visibility:public" ])
exports_files(["bin/node", "bin/npm", "bin/tsc", "bin/yarn", "bin/bower"])
"""

def _mirror_path(ctx, workspace_root, path):
    src = "/".join([workspace_root, path])
    dst = "/".join([ctx.path("."), path])
    ctx.symlink(src, dst)

def _node_toolchain_impl(ctx):
    os = ctx.os.name
    if os == "linux":
        noderoot = ctx.path(ctx.attr._linux).dirname
    elif os == "mac os x":
        noderoot = ctx.path(ctx.attr._darwin).dirname
    else:
        fail("Unsupported operating system: " + os)

    # upgrade bundled npm to specific version
    execute(ctx, ["%s/bin/node" % noderoot, "%s/bin/npm" % noderoot, "install", "-g", "--prefix", noderoot, "npm@%s" % ctx.attr.npm_version], path = "%s/bin" % noderoot)
    execute(ctx, ["%s/bin/node" % noderoot, "%s/bin/npm" % noderoot, "install", "-g", "--prefix", noderoot, "typescript@%s" % ctx.attr.ts_version], path = "%s/bin" % noderoot)
    execute(ctx, ["%s/bin/node" % noderoot, "%s/bin/npm" % noderoot, "install", "-g", "--prefix", noderoot, "yarn@%s" % ctx.attr.yarn_version], path = "%s/bin" % noderoot)
    execute(ctx, ["%s/bin/node" % noderoot, "%s/bin/npm" % noderoot, "install", "-g", "--prefix", noderoot, "bower@%s" % ctx.attr.bower_version], path = "%s/bin" % noderoot)

    _mirror_path(ctx, noderoot, "bin")
    _mirror_path(ctx, noderoot, "include")
    _mirror_path(ctx, noderoot, "lib")
    _mirror_path(ctx, noderoot, "share")

    ctx.file("WORKSPACE", "workspace(name = '%s')" % ctx.name)
    ctx.file("BUILD", NODE_TOOLCHAIN_BUILD_FILE)

_node_toolchain = repository_rule(
    _node_toolchain_impl,
    attrs = {
        "npm_version": attr.string(mandatory = True),
        "ts_version": attr.string(mandatory = True),
        "yarn_version": attr.string(mandatory = True),
        "bower_version": attr.string(mandatory = True),
        "_linux": attr.label(
            default = Label("@nodejs_linux_amd64//:WORKSPACE"),
            allow_files = True,
            single_file = True,
        ),
        "_darwin": attr.label(
            default = Label("@nodejs_darwin_amd64//:WORKSPACE"),
            allow_files = True,
            single_file = True,
        ),
    },
)

def node_repositories(
        node_version = "8.11.4",
        linux_sha256 = "c69abe770f002a7415bd00f7ea13b086650c1dd925ef0c3bf8de90eabecc8790",
        darwin_sha256 = "aa1de83b388581d0d9ec3276f4526ee67e17e0f1bc0deb5133f960ce5dc9f1ef",
        npm_version = "5.5.1",
        ts_version = "2.5.3",
        yarn_version = "1.2.1",
        bower_version = "1.8.2"):
    http_archive(
        name = "nodejs_linux_amd64",
        url = "https://nodejs.org/dist/v{version}/node-v{version}-linux-x64.tar.gz".format(version = node_version),
        type = "tar.gz",
        strip_prefix = "node-v{version}-linux-x64".format(version = node_version),
        sha256 = linux_sha256,
        build_file_content = "exports_files([\"WORKSPACE\"])",
    )

    http_archive(
        name = "nodejs_darwin_amd64",
        url = "https://nodejs.org/dist/v{version}/node-v{version}-darwin-x64.tar.gz".format(version = node_version),
        type = "tar.gz",
        strip_prefix = "node-v{version}-darwin-x64".format(version = node_version),
        sha256 = darwin_sha256,
        build_file_content = "exports_files([\"WORKSPACE\"])",
    )

    _node_toolchain(
        name = "com_happyco_rules_node_toolchain",
        npm_version = npm_version,
        ts_version = ts_version,
        yarn_version = yarn_version,
        bower_version = bower_version,
    )
