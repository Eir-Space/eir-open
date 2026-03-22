#!/usr/bin/env node

/**
 * Production entrypoint for Fly.io.
 * Starts the Next.js server and schedules periodic news fetching.
 */

import { spawn } from 'child_process';
import { existsSync, copyFileSync } from 'fs';
import { join } from 'path';

const DATA_DIR = process.env.DATA_DIR || join(process.cwd(), 'data');
const STORIES_FILE = join(DATA_DIR, 'stories.json');
const BUNDLED_STORIES = join(process.cwd(), 'data', 'stories.json');
const FETCH_INTERVAL_MS = 6 * 60 * 60 * 1000; // 6 hours

// Seed persistent volume with bundled stories if empty
if (!existsSync(STORIES_FILE) && existsSync(BUNDLED_STORIES)) {
  console.log('[start] Seeding persistent volume with bundled stories');
  copyFileSync(BUNDLED_STORIES, STORIES_FILE);
}

// Start Next.js
const next = spawn('npm', ['run', 'start', '--', '--hostname', '0.0.0.0', '--port', '3000'], {
  stdio: 'inherit',
  env: { ...process.env },
});

next.on('exit', (code) => {
  console.error(`[start] Next.js exited with code ${code}`);
  process.exit(code || 1);
});

// Schedule news fetching
async function fetchNews() {
  console.log(`[cron] Fetching news at ${new Date().toISOString()}`);
  try {
    const { fetchWithWebSearch } = await import('../lib/news-fetcher.js');
    const { addStories, readStories } = await import('../lib/story-store.js');

    const existing = readStories();
    const stories = await fetchWithWebSearch(existing);
    const result = addStories(stories);
    console.log(`[cron] Added ${result.added} new stories (${result.total} total)`);
  } catch (err) {
    console.error('[cron] Failed to fetch news:', err.message);
  }
}

// Initial fetch after a 30-second startup delay
setTimeout(fetchNews, 30_000);

// Then every 6 hours
setInterval(fetchNews, FETCH_INTERVAL_MS);

console.log(`[start] News fetch scheduled every ${FETCH_INTERVAL_MS / 3600000}h`);
