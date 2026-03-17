// @ts-check
import { defineConfig } from 'astro/config';
import { fileURLToPath } from 'node:url';
import { join } from 'node:path';
import react from '@astrojs/react';
import tailwindcss from '@tailwindcss/vite';

const __dirname = fileURLToPath(new URL('.', import.meta.url));

// https://astro.build/config
export default defineConfig({
  site: 'https://open.eir.space',
  base: '/',
  integrations: [react()],

  vite: {
    plugins: [tailwindcss()],
    resolve: {
      alias: { '@': join(__dirname, 'src') },
    },
  },
});
