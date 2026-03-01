// @ts-check
import { defineConfig } from 'astro/config';
import { fileURLToPath } from 'node:url';
import { join } from 'node:path';
import starlight from '@astrojs/starlight';

import react from '@astrojs/react';
import tailwindcss from '@tailwindcss/vite';

const __dirname = fileURLToPath(new URL('.', import.meta.url));

// https://astro.build/config
export default defineConfig({
  site: 'https://eir-space.github.io',
  base: '/eir-open',

  integrations: [
    starlight({
      title: 'Eir Open',
      logo: {
        light: './src/assets/logos/light-circle.svg',
        dark: './src/assets/logos/dark-circle.svg',
      },
      favicon: '/favicon.svg',
      customCss: ['./src/styles/global.css'],
      components: {
        ThemeProvider: './src/components/ThemeProvider.astro',
        ThemeSelect: './src/components/ThemeSelect.astro',
      },
      social: [
        { icon: 'github', label: 'GitHub', href: 'https://github.com/eir-space/eir-open' },
      ],
      editLink: {
        base: 'https://github.com/eir-space/eir-open/edit/main/site/src/content/docs',
        text: 'Edit this page',
      },
      sidebar: [
        { label: 'Overview', slug: 'docs' },
        {
          label: 'Get Started',
          items: [
            { slug: 'docs/quickstart', label: 'Quickstart' },
            { slug: 'docs/agent-integration', label: 'Agent Integration' },
            { slug: 'docs/mcp-server', label: 'MCP Server' },
            { slug: 'docs/openclaw-integration', label: 'OpenClaw Integration' },
          ],
        },
        {
          label: 'Projects',
          items: [
            { slug: 'docs/health-md-standard', label: 'EIR Health Data Standard' },
            { slug: 'docs/us-medications', label: 'US FDA Medications' },
            { slug: 'docs/swedish-medications', label: 'Swedish Medications' },
            { slug: 'docs/eir-open-apps', label: 'Eir Open Apps' },
          ],
        },
        { label: 'Contributing', slug: 'docs/contributing' },
      ],
      expressiveCode: {
        styleOverrides: {
          borderRadius: '0.75rem',
          borderColor: 'var(--border-subtle)',
          borderWidth: '1px',
          frames: {
            shadowColor: 'rgba(26, 47, 53, 0.12)',
            shadowBlur: '12px',
            shadowOffsetX: '0',
            shadowOffsetY: '4px',
          },
        },
      },
    }),
    react(),
  ],

  vite: {
    plugins: [tailwindcss()],
    resolve: {
      alias: { '@': join(__dirname, 'src') },
    },
  },
});