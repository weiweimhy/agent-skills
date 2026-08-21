---
name: semi-mcp-setup
description: Configure, update, verify, or troubleshoot the project-scoped Semi Design MCP for Codex. Use when the user explicitly asks to install or diagnose Semi MCP, not for ordinary Semi UI work.
---

# Semi MCP Setup

Configure the official Semi Design MCP as a project-scoped Codex server, then
verify that its documentation and source-inspection tools can be discovered.

## Scope and authorization

- Read the current project instructions and existing `.codex/config.toml` before
  changing anything. Preserve other MCP servers and settings.
- A request to inspect installation is read-only. Writing configuration or
  starting `npx` (which may download and execute the package) requires explicit
  user authorization to install or configure Semi MCP.
- Prefer project-scoped `.codex/config.toml` when the project has that policy.
  Do not change the user's global Codex configuration unless they explicitly
  request global installation.
- Read the current [Semi MCP documentation](https://semi.design/zh-CN/start/mcp-skills)
  before selecting a package or command. The public package and the ByteDance
  intranet package are different; ask which environment applies when it is not
  established by the user's request or local configuration.

## Workflow

1. Inspect the project config, `codex mcp list`, installed Semi version, and
   Node/npm versions. Semi recommends Node.js `> 20.19.0` and npm `> 11.3.0`.
   Warn about incompatible versions before configuration.
2. Resolve and pin the intended package version rather than using an unbounded
   `latest` specifier. For the public package, query the npm registry only with
   permission when network access requires it.
3. Add or update the `semi-mcp` table in the project configuration using the
   exact-version template in [the configuration reference](references/semi-mcp.md).
   Retain unrelated configuration and use a startup timeout suitable for a first
   `npx` download.
4. Run `codex mcp list` from the project directory and confirm that `semi-mcp`
   is enabled with the expected `npx` command and pinned argument.
5. When the user authorized a full installation check, perform the stdio
   initialization and `tools/list` verification described in
   [the verification reference](references/semi-mcp.md). Stop the test process
   after receiving the result.
6. Explain that an already-running Codex task cannot acquire newly configured
   tools. Ask the user to open a new local Codex task (or restart the client)
   before claiming that Semi MCP is available to the agent.

## Maintenance boundaries

- Semi MCP is a development tool; it must not be added to application runtime
  dependencies or browser bundles.
- If project documentation says Semi MCP is absent or uses a different package,
  update the affected statement in the same focused change.
- Do not pre-emptively install packages globally. The official global-install
  workaround is only relevant after the documented dependency error occurs and
  the user authorizes that recovery.
