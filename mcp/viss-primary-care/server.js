#!/usr/bin/env node
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';

import { createVissMcpServer } from './server-core.js';

const server = createVissMcpServer();
await server.connect(new StdioServerTransport());
