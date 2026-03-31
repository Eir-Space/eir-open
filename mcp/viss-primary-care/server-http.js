#!/usr/bin/env node
import http from 'node:http';
import { URL } from 'node:url';

import { StreamableHTTPServerTransport } from '@modelcontextprotocol/sdk/server/streamableHttp.js';
import { SSEServerTransport } from '@modelcontextprotocol/sdk/server/sse.js';
import { createVissMcpServer } from './server-core.js';

const HOST = process.env.HOST || '0.0.0.0';
const PORT = Number(process.env.PORT || 8080);
const MCP_PATH = process.env.MCP_PATH || '/mcp';
const SSE_PATH = process.env.SSE_PATH || '/sse';
const SSE_MESSAGES_PATH = process.env.SSE_MESSAGES_PATH || '/messages';
const HEALTH_PATH = process.env.HEALTH_PATH || '/health';

/**
 * Keep legacy SSE transports alive across requests so /messages can route to the same session.
 */
const legacySseTransports = new Map();

function getSessionIdFromUrl(url = '') {
  const parsed = new URL(url, 'http://localhost');

  return parsed.searchParams.get('sessionId');
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];

    req.on('data', (chunk) => {
      chunks.push(chunk);
    });

    req.on('error', (error) => {
      reject(error);
    });

    req.on('end', () => {
      const body = Buffer.concat(chunks);
      resolve(body.toString('utf8'));
    });
  });
}

function parseJsonBody(raw) {
  if (!raw) return undefined;

  try {
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

function writeJson(res, statusCode, payload, headers = {}) {
  const body = JSON.stringify(payload);
  res.writeHead(statusCode, {
    ...headers,
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(body),
  });
  res.end(body);
}

const server = http.createServer(async (req, res) => {
  const pathname = new URL(req.url || '/', 'http://localhost').pathname;

  try {
    if (pathname === HEALTH_PATH) {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ status: 'ok' }));
      return;
    }

    if (pathname === SSE_PATH) {
      if (req.method !== 'GET') {
        writeJson(
          res,
          405,
          {
            jsonrpc: '2.0',
            error: { code: -32000, message: 'Method not allowed.' },
            id: null,
          },
          { Allow: 'GET' },
        );
        return;
      }

      try {
        const transport = new SSEServerTransport(SSE_MESSAGES_PATH, res);
        const mcpServer = createVissMcpServer();

        legacySseTransports.set(transport.sessionId, transport);
        transport.onclose = () => {
          legacySseTransports.delete(transport.sessionId);
          mcpServer.close().catch(() => {
            // Ignore shutdown errors for best-effort cleanup.
          });
        };

        await mcpServer.connect(transport);
      } catch (error) {
        console.error('Error establishing SSE stream:', error);
        if (!res.headersSent) {
          writeJson(res, 500, {
            jsonrpc: '2.0',
            error: { code: -32603, message: 'Failed to establish SSE stream' },
            id: null,
          });
        }
      }

      return;
    }

    if (pathname === SSE_MESSAGES_PATH) {
      if (req.method !== 'POST') {
        writeJson(
          res,
          405,
          {
            jsonrpc: '2.0',
            error: { code: -32000, message: 'Method not allowed.' },
            id: null,
          },
          { Allow: 'POST' },
        );
        return;
      }

      const sessionId = req.url ? getSessionIdFromUrl(req.url) : null;
      const transport = sessionId ? legacySseTransports.get(sessionId) : null;

      if (!sessionId || !transport) {
        writeJson(
          res,
          404,
          {
            jsonrpc: '2.0',
            error: { code: -32600, message: 'Session not found. Establish /sse first.' },
            id: null,
          },
        );
        return;
      }

      const rawBody = await readBody(req);
      const parsedBody = parseJsonBody(rawBody);

      if (parsedBody === null) {
        writeJson(
          res,
          400,
          {
            jsonrpc: '2.0',
            error: { code: -32700, message: 'Parse error' },
            id: null,
          },
        );
        return;
      }

      await transport.handlePostMessage(req, res, parsedBody);
      return;
    }

    if (pathname !== MCP_PATH) {
      writeJson(
        res,
        404,
        {
          jsonrpc: '2.0',
          error: { code: -32601, message: 'Not Found' },
          id: null,
        },
      );
      return;
    }

    if (req.method === 'GET' || req.method === 'DELETE') {
      writeJson(
        res,
        405,
        {
          jsonrpc: '2.0',
          error: { code: -32000, message: 'Method not allowed.' },
          id: null,
        },
        { Allow: 'POST' },
      );
      return;
    }

    if (req.method !== 'POST') {
      writeJson(
        res,
        405,
        {
          jsonrpc: '2.0',
          error: { code: -32000, message: 'Method not allowed.' },
          id: null,
        },
      );
      return;
    }

    const rawBody = await readBody(req);
    const parsedBody = parseJsonBody(rawBody);

    if (parsedBody === null) {
      writeJson(res, 400, {
        jsonrpc: '2.0',
        error: { code: -32700, message: 'Parse error' },
        id: null,
      });
      return;
    }

    const mcpServer = createVissMcpServer();
    const transport = new StreamableHTTPServerTransport({
      sessionIdGenerator: undefined,
      enableJsonResponse: true,
    });

    await mcpServer.connect(transport);
    await transport.handleRequest(req, res, parsedBody);

    res.on('close', async () => {
      await transport.close();
      await mcpServer.close();
    });
    return;
  } catch (error) {
    console.error('Error handling MCP request:', error);

    if (!res.headersSent) {
      writeJson(res, 500, {
        jsonrpc: '2.0',
        error: {
          code: -32603,
          message: 'Internal server error',
        },
        id: null,
      });
    }
  }
});

server.listen(PORT, HOST, () => {
  console.log(`VISS MCP Streamable HTTP server listening on http://${HOST}:${PORT}${MCP_PATH}`);
});

process.on('SIGINT', async () => {
  console.log('Shutting down VISS MCP server...');
  server.close(() => {
    process.exit(0);
  });
});

process.on('SIGTERM', async () => {
  console.log('Shutting down VISS MCP server...');
  server.close(() => {
    process.exit(0);
  });
});
