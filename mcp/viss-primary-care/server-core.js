#!/usr/bin/env node
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawn } from 'node:child_process';
import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const REPO_ROOT = path.resolve(__dirname, '../..');
const SKILL_SCRIPT = path.join(
  REPO_ROOT,
  'skills',
  'viss-primary-care',
  'scripts',
  'viss-primary-care.js',
);

const MAX_TOOL_TIMEOUT_MS = 45_000;

function runVissTool(action, args = {}) {
  const payload = { action, ...args };
  return new Promise((resolve, reject) => {
    const proc = spawn(
      process.execPath,
      [SKILL_SCRIPT, JSON.stringify(payload)],
      {
        cwd: REPO_ROOT,
        env: { ...process.env },
        stdio: ['ignore', 'pipe', 'pipe'],
      },
    );

    let stdoutBuffer = '';
    let stderrBuffer = '';
    const timeout = setTimeout(() => {
      proc.kill('SIGKILL');
      reject(new Error(`VISS tool timed out after ${MAX_TOOL_TIMEOUT_MS}ms`));
    }, MAX_TOOL_TIMEOUT_MS);

    proc.stdout.setEncoding('utf8');
    proc.stdout.on('data', (chunk) => {
      stdoutBuffer += chunk;
    });

    proc.stderr.setEncoding('utf8');
    proc.stderr.on('data', (chunk) => {
      stderrBuffer += chunk;
    });

    proc.on('error', (error) => {
      clearTimeout(timeout);
      reject(error);
    });

    proc.on('close', (code) => {
      clearTimeout(timeout);
      const text = stdoutBuffer.trim();
      if (!text) {
        reject(new Error(`No output from VISS script. ${stderrBuffer}`.trim()));
        return;
      }

      try {
        const data = JSON.parse(text);
        if (code !== 0 && !data.error) {
          reject(
            new Error(
              `VISS script failed with exit code ${code}: ${stderrBuffer || text}`,
            ),
          );
          return;
        }

        resolve(data);
      } catch (error) {
        reject(
          new Error(
            `Failed to parse VISS response JSON (${error.message}): ${text.slice(0, 500)}`,
          ),
        );
      }
    });
  });
}

async function runTool(name, args) {
  if (name === 'viss_query') {
    return runVissTool('query', {
      query: args?.query,
      q: args?.query,
      limit: args?.limit,
      include_details: args?.include_details,
      detail_limit: args?.detail_limit,
    });
  }

  if (name === 'viss_lookup') {
    return runVissTool('lookup', {
      url: args?.url,
      path: args?.path,
      slug: args?.slug,
      max_sections: args?.max_sections ?? 12,
    });
  }

  if (name === 'viss_areas') {
    return runVissTool('areas');
  }

  throw new Error(`Unknown tool: ${name}`);
}

function toTextResponse(result) {
  return {
    content: [
      {
        type: 'text',
        text: JSON.stringify(result, null, 2),
      },
    ],
  };
}

function createVissMcpServer() {
  const server = new Server(
    {
      name: 'viss-primary-care-mcp',
      version: '1.0.0',
    },
    {
      capabilities: {
        tools: {},
      },
    },
  );

  server.setRequestHandler(ListToolsRequestSchema, async () => ({
    tools: [
      {
        name: 'viss_query',
        description:
          'Search VISS and return ranked primary-care pages with direct links to https://viss.nu guidance pages.',
        inputSchema: {
          type: 'object',
          properties: {
            query: {
              type: 'string',
              description:
                'Search query in Swedish/clinical terms (e.g. "hjärtinfarkt", "diabetes").',
            },
            limit: {
              type: 'number',
              description:
                'Maximum number of search results to return. 1-20. Default 10.',
              minimum: 1,
              maximum: 20,
            },
            include_details: {
              type: 'boolean',
              description:
                'If true, fetch short section previews for top results to provide immediate context.',
            },
            detail_limit: {
              type: 'number',
              description:
                'How many top results to hydrate with details when include_details is true.',
              minimum: 1,
              maximum: 5,
            },
          },
          required: ['query'],
        },
      },
      {
        name: 'viss_lookup',
        description:
          'Lookup a specific VISS primary-care page and return concise, sectioned clinical guidance with reference links.',
        inputSchema: {
          type: 'object',
          properties: {
            url: {
              type: 'string',
              description: 'Full https://viss.nu URL to a /kunskapsstod page.',
            },
            path: {
              type: 'string',
              description:
                'Alternative internal path to a page, e.g. /kunskapsstod/vardprogram/akut-kranskarlssjukdom.',
            },
            slug: {
              type: 'string',
              description:
                'Alternative page slug, e.g. akut-kranskarlssjukdom (applies under /kunskapsstod/vardprogram/).',
            },
            max_sections: {
              type: 'number',
              description:
                'Maximum number of sections to include in lookup output. 1-20. Default 12.',
              minimum: 1,
              maximum: 20,
            },
          },
        },
      },
      {
        name: 'viss_areas',
        description:
          'List VISS primary-care knowledge areas from https://viss.nu/kunskapsstod with names and links.',
        inputSchema: {
          type: 'object',
          properties: {},
        },
      },
    ],
  }));

  server.setRequestHandler(CallToolRequestSchema, async (request) => {
    const { name, arguments: args = {} } = request.params;

    try {
      const result = await runTool(name, args);
      return toTextResponse(result);
    } catch (error) {
      return {
        isError: true,
        content: [
          {
            type: 'text',
            text: error instanceof Error ? error.message : 'Unknown error',
          },
        ],
      };
    }
  });

  return server;
}

export { createVissMcpServer };
