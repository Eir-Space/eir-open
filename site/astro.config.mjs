// @ts-check
import { defineConfig } from 'astro/config';
import { fileURLToPath } from 'node:url';
import { join } from 'node:path';
import mdx from '@astrojs/mdx';
import react from '@astrojs/react';
import expressiveCode from 'astro-expressive-code';
import tailwindcss from '@tailwindcss/vite';

const __dirname = fileURLToPath(new URL('.', import.meta.url));

// https://astro.build/config
export default defineConfig({
  site: 'https://open.eir.space',
  base: '/',
  integrations: [
    expressiveCode({
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
    }),
    mdx(),
    react(),
  ],

  vite: {
    plugins: [tailwindcss()],
    resolve: {
      alias: { '@': join(__dirname, 'src') },
    },
  },
});
