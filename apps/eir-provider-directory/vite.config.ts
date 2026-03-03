import { defineConfig } from 'vite'
import vinext from 'vinext'
import { cloudflare } from '@cloudflare/vite-plugin'

export default defineConfig(() => {
  const plugins = [vinext()]

  if (process.env.CLOUDFLARE_DEPLOY === '1') {
    plugins.push(cloudflare())
  }

  return { plugins }
})
