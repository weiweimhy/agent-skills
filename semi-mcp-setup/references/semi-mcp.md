# Semi MCP configuration and verification

## Official source and compatibility

- Source: [Semi MCP/Skills](https://semi.design/zh-CN/start/mcp-skills).
- Semi recommends Node.js later than `20.19.0` and npm later than `11.3.0`.
- The public server package is `@douyinfe/semi-mcp`. ByteDance intranet users
  must use `@ies/semi-mcp-bytedance` instead; do not infer intranet status.
- Semi documents stable MCP knowledge beginning with Semi `2.90.2`. Warn if the
  project uses an earlier version, but do not silently upgrade the application.

Resolve the public package version before editing configuration:

```powershell
npm view @douyinfe/semi-mcp version
```

Network access may need approval. Pin the returned reviewed version in the
configuration rather than substituting `latest`.

## Codex project configuration

Codex uses TOML tables named `mcp_servers.<server-name>`, while Semi's guide
shows the equivalent JSON structure for other clients. Keep unrelated tables in
place and add or update only this table:

```toml
[mcp_servers.semi-mcp]
command = "npx"
args = ["-y", "@douyinfe/semi-mcp@<reviewed-version>"]
startup_timeout_sec = 30
```

For a confirmed ByteDance intranet environment, replace only the package name
with `@ies/semi-mcp-bytedance` and pin its reviewed version. Do not use this
project template to edit `~/.codex/config.toml` unless the user explicitly asks
for global setup.

## Registration and service checks

First confirm registration from the project root:

```powershell
codex mcp list
```

It should show an enabled `semi-mcp` entry whose command is `npx` and whose
arguments include the pinned package.

For a full service check, start the configured package in a PTY and send a
line-delimited JSON-RPC initialization request:

```json
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"semi-mcp-verification","version":"1.0.0"}}}
```

After a successful response, send the initialized notification followed by the
tool listing request:

```json
{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}
{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}
```

Expect the server to identify itself as `semi-mcp` and to expose the read-only
tools `get_semi_document`, `get_semi_code_block`,
`get_component_file_list`, `get_file_code`, and `get_function_code`. Terminate
the verification process once the response arrives.

## Recovery

If the server reports the documented `oxc-parser` dependency-resolution error,
consult the current Semi guide. Its global npm workaround is a recovery action,
not part of routine setup; explain the external change and obtain fresh user
authorization before using it.
