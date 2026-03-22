import { readFileSync, writeFileSync, existsSync } from 'fs';
import { join } from 'path';

function dataPath() {
  const dir = process.env.DATA_DIR || join(process.cwd(), 'data');
  return join(dir, 'stories.json');
}

export function readStories() {
  const p = dataPath();
  if (!existsSync(p)) return [];
  const raw = readFileSync(p, 'utf-8');
  return JSON.parse(raw);
}

export function writeStories(stories) {
  writeFileSync(dataPath(), JSON.stringify(stories, null, 2));
}

export function addStories(newStories) {
  const existing = readStories();
  const existingSlugs = new Set(existing.map((s) => s.slug));
  const existingUrls = new Set(existing.map((s) => s.sourceUrl));
  const unique = newStories.filter(
    (s) => !existingSlugs.has(s.slug) && !existingUrls.has(s.sourceUrl),
  );
  const merged = [...unique, ...existing];
  writeStories(merged);
  return { added: unique.length, total: merged.length };
}

export function getStoryBySlug(slug) {
  return readStories().find((s) => s.slug === slug) || null;
}

export function listByCategory(category) {
  const stories = readStories();
  if (!category) return stories;
  return stories.filter((s) => s.category === category);
}

export function getCategories() {
  const stories = readStories();
  return [...new Set(stories.map((s) => s.category))].sort();
}
