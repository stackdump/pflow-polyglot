"""Minimal `nodejs_binary` / `nodejs_test` rules over the rules_nodejs toolchain.

rules_nodejs 6.x ships only the Node.js toolchain — `nodejs_binary`/`js_test`
live in aspect_rules_js, which is npm-lockfile oriented and the wrong fit for
this repo's dependency-free CommonJS. These rules just run
`node <entry_point>` with the hermetic node, staging `data` into runfiles.
Relative `require()` calls in the entry script resolve against the script's own
location in the runfiles tree.

Adapted from beats-bitwrap-io/tools/nodejs_test.bzl (which has the test rule
only); the binary variant is what `//parity:cross_language_parity_test` needs,
since it captures each implementation's stdout rather than asserting inside it.
"""

def _nodejs_impl(ctx):
    toolchain = ctx.toolchains["@rules_nodejs//nodejs:toolchain_type"]
    node = toolchain.nodeinfo.node
    entry = ctx.file.entry_point

    launcher = ctx.actions.declare_file(ctx.label.name + ".sh")
    ctx.actions.write(
        output = launcher,
        is_executable = True,
        content = """#!/usr/bin/env bash
set -euo pipefail
# Resolve node and the entry script against the runfiles tree, whether we were
# launched by `bazel test` (cwd = runfiles root) or as a data dependency of
# another target (cwd may be anywhere, but RUNFILES_DIR / $0.runfiles is set).
root="${{RUNFILES_DIR:-}}"
if [[ -z "$root" ]]; then
  if [[ -d "$0.runfiles" ]]; then
    root="$0.runfiles"
  else
    root="$PWD"
  fi
fi
node="$root/{workspace}/{node}"
[[ -x "$node" ]] || node="$root/{node}"
[[ -x "$node" ]] || node="{node}"
entry="$root/{workspace}/{entry}"
[[ -f "$entry" ]] || entry="{entry}"
exec "$node" "$entry" "$@"
""".format(
            node = node.short_path,
            entry = entry.short_path,
            workspace = ctx.workspace_name,
        ),
    )

    runfiles = ctx.runfiles(files = [entry] + ctx.files.data)
    runfiles = runfiles.merge(toolchain.default.default_runfiles)

    return [DefaultInfo(executable = launcher, runfiles = runfiles)]

_ATTRS = {
    "entry_point": attr.label(allow_single_file = True, mandatory = True),
    "data": attr.label_list(allow_files = True),
}

nodejs_binary = rule(
    implementation = _nodejs_impl,
    executable = True,
    attrs = _ATTRS,
    toolchains = ["@rules_nodejs//nodejs:toolchain_type"],
)

nodejs_test = rule(
    implementation = _nodejs_impl,
    test = True,
    attrs = _ATTRS,
    toolchains = ["@rules_nodejs//nodejs:toolchain_type"],
)
