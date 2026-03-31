# VISS Primary Care MCP Server

This MCP server exposes VISS primary care knowledge search and lookup as tools usable in MCP-capable clients (ChatGPT, Claude Desktop, Cursor, etc.).

It runs outside the skills folder and calls:

- `skills/viss-primary-care/scripts/viss-primary-care.js`

## Install

```bash
cd /path/to/eir-open/mcp/viss-primary-care
npm install
```

## Run

### Local stdio mode (for local clients)

```bash
npm start
```

### Local HTTP mode (for Cloud Run)

```bash
PORT=8080 MCP_PATH=/mcp npm run start:http
```

## MCP Tools

- `viss_query`
  - Search `viss.nu` primary-care guidance
  - Returns ranked links to pages and optional short detail snippets
- `viss_lookup`
  - Lookup a specific page by `url`, `path`, or `slug`
  - Returns title, snippets, metadata, and related page links
- `viss_areas`
  - Lists knowledge area index pages with links from `https://viss.nu/kunskapsstod`

## Cloud Run deployment

### 1) Build and deploy

```bash
gcloud run deploy viss-primary-care-mcp \
  --source /path/to/eir-open \
  --dockerfile mcp/viss-primary-care/Dockerfile \
  --region europe-north1 \
  --platform managed \
  --allow-unauthenticated
```

If your organization requires auth, remove `--allow-unauthenticated` and configure auth as needed.

After deploy, your endpoint will be:

`https://<service>-<hash>-<region>.run.app/mcp`

Example for this repository currently deployed in Stockholm:

`https://viss-primary-care-mcp-2oe77t2o2a-lz.a.run.app/mcp`

Health check endpoint:

`https://<service>-<hash>-<region>.run.app/health`

## Client config examples

Use this style in MCP clients that support remote Streamable HTTP endpoints:

```json
{
  "mcpServers": {
    "viss-primary-care": {
      "url": "https://<service>.run.app/mcp"
    }
  }
}
```

For ChatGPT clients that require `/sse`, configure the endpoint as:

```json
{
  "mcpServers": {
    "viss-primary-care": {
      "url": "https://<service>.run.app/sse"
    }
  }
}
```

If your ChatGPT setup also posts to `/messages`, use this session flow:

```text
GET  /sse
POST /messages?sessionId=<session-id>
```

For stdio-only MCP clients, keep the local command style:

### Claude Desktop / local stdio config
```json
{
  "command": "node",
  "args": ["/path/to/eir-open/mcp/viss-primary-care/server.js"]
}
```

## Quick checks

1. Ensure the skill command works:

```bash
node ../../skills/viss-primary-care/scripts/viss-primary-care.js --action areas
```

2. Start server and connect via your MCP client:

```bash
npm start
```

3. Verify Cloud Run-compatible HTTP endpoint locally:

```bash
npm run start:http
cat >/tmp/mcp-init.json <<'EOF'
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/list",
  "params": {}
}
EOF
curl -s -X POST http://localhost:8080/mcp \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  --data @/tmp/mcp-init.json
```
