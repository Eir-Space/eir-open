#!/usr/bin/env node

/**
 * Fetch and structure AI healthcare news using OpenAI with web search.
 *
 * Usage:
 *   OPENAI_API_KEY=sk-... node scripts/fetch-news.js
 *   node scripts/fetch-news.js --dry-run    # print stories without saving
 *
 * Run on a cron (e.g. every 6 hours) to keep the site fresh:
 *   Example cron entry: run every 6 hours from the app directory.
 */

import { fetchWithWebSearch } from '../lib/news-fetcher.js';
import { addStories, readStories } from '../lib/story-store.js';

const dryRun = process.argv.includes('--dry-run');

async function main() {
  console.log(`[${new Date().toISOString()}] Fetching AI healthcare news...`);

  try {
    const existing = readStories();
    console.log(`${existing.length} stories already published`);

    const stories = await fetchWithWebSearch(existing);
    console.log(`Fetched ${stories.length} new verified stories`);

    if (dryRun) {
      console.log('\n--- DRY RUN (not saving) ---\n');
      for (const story of stories) {
        console.log(`  [${story.category}] ${story.title}`);
        console.log(`    ${story.summary}`);
        console.log(`    Source: ${story.source} (${story.sourceUrl})`);
        console.log();
      }
      return;
    }

    const result = addStories(stories);
    console.log(`Added ${result.added} new stories (${result.total} total)`);

    for (const story of stories) {
      console.log(`  + [${story.category}] ${story.title}`);
    }
  } catch (err) {
    console.error('Failed to fetch news:', err.message);
    process.exit(1);
  }
}

main();
