import OpenAI from 'openai';

const SEARCH_QUERIES = [
  'AI healthcare clinical trials',
  'artificial intelligence medical diagnosis breakthrough',
  'LLM healthcare applications regulation',
  'AI drug discovery latest developments',
  'machine learning radiology pathology',
  'AI mental health digital therapeutics',
  'healthcare AI startups funding',
  'FDA AI medical device approval',
  'AI electronic health records EHR',
  'generative AI clinical decision support',
  'AI ambient scribe clinical documentation',
  'EU AI Act healthcare medical devices',
  'AI genomics rare disease diagnosis',
  'digital health AI wearables',
];

function pickQueries(count = 4) {
  const shuffled = [...SEARCH_QUERIES].sort(() => Math.random() - 0.5);
  return shuffled.slice(0, count);
}

/**
 * Check if a URL is reachable (2xx or 403 paywall = OK, 404/5xx = bad).
 * Returns true if the URL appears to point to a real page.
 */
async function verifyUrl(url) {
  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 10_000);
    const res = await fetch(url, {
      method: 'HEAD',
      signal: controller.signal,
      redirect: 'follow',
      headers: { 'User-Agent': 'EirNewsBot/1.0' },
    });
    clearTimeout(timeout);
    // 2xx = exists, 403 = paywall (article exists), 405 = HEAD not allowed (try GET)
    if (res.status >= 200 && res.status < 400) return true;
    if (res.status === 403) return true;
    if (res.status === 405) {
      // Some sites reject HEAD, retry with GET
      const res2 = await fetch(url, {
        method: 'GET',
        signal: AbortSignal.timeout(10_000),
        redirect: 'follow',
        headers: { 'User-Agent': 'EirNewsBot/1.0' },
      });
      return res2.status >= 200 && res2.status < 500;
    }
    return false;
  } catch {
    return false;
  }
}

function parseStories(text) {
  const trimmed = text.trim();
  const jsonStr = trimmed.startsWith('[') ? trimmed : trimmed.match(/\[[\s\S]*\]/)?.[0];
  if (!jsonStr) throw new Error('Failed to parse stories from LLM response');
  const stories = JSON.parse(jsonStr);
  const now = new Date().toISOString();
  return stories.map((s) => ({
    ...s,
    fetchedAt: s.fetchedAt || now,
    id: s.slug,
  }));
}

/**
 * Fetch and structure news using OpenAI with web search.
 * Accepts existing stories to avoid duplicates and verify URLs.
 */
export async function fetchWithWebSearch(existingStories = []) {
  const client = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
  const queries = pickQueries(4);

  // Build context about what we already have so the LLM avoids duplicates
  const existingContext =
    existingStories.length > 0
      ? `\n\nIMPORTANT — These stories are ALREADY published. Do NOT return any of them:\n${existingStories
          .map((s) => `- "${s.title}" (${s.sourceUrl})`)
          .join('\n')}\n`
      : '';

  const response = await client.responses.create({
    model: 'gpt-5.4',
    tools: [{ type: 'web_search_preview' }],
    input: `Search the web for the latest news about AI in healthcare. Use these search angles:

${queries.map((q, i) => `${i + 1}. ${q}`).join('\n')}

Search for each angle, then compile the most significant and recent stories into structured articles.
${existingContext}
You are a healthcare AI news editor. For each NEW story you find, create a structured article. Return a JSON array of story objects.

Each story object must have:
- "title": compelling headline (string)
- "slug": URL-friendly slug derived from title (string, lowercase, hyphens, no special chars)
- "summary": 2-3 sentence summary (string)
- "body": full article body in markdown, 3-5 paragraphs with analysis and context (string)
- "category": one of "clinical", "research", "regulation", "industry", "technology", "opinion" (string)
- "tags": array of relevant tags like "radiology", "drug-discovery", "FDA", "LLM", "diagnostics" etc. (string[])
- "source": original publication name (string)
- "sourceUrl": the EXACT URL of the article you found — must be a real, specific article URL, NOT a homepage (string)
- "publishedAt": ISO date string of when the original was published (string)
- "fetchedAt": "${new Date().toISOString()}"

Return 5-8 stories. Only include stories where you have a real, specific article URL.

IMPORTANT: Return ONLY a valid JSON array. No markdown fences, no preamble.

Today's date: ${new Date().toISOString().split('T')[0]}`,
  });

  const text = response.output_text;
  if (!text) throw new Error('No text response from OpenAI');

  const candidates = parseStories(text);

  // Build dedup sets from existing stories
  const existingUrls = new Set(existingStories.map((s) => s.sourceUrl));
  const existingSlugs = new Set(existingStories.map((s) => s.slug));

  // Filter out duplicates by URL or slug before verification
  const fresh = candidates.filter(
    (s) => !existingUrls.has(s.sourceUrl) && !existingSlugs.has(s.slug),
  );

  // Verify each URL in parallel
  const verified = [];
  const results = await Promise.all(
    fresh.map(async (story) => {
      const ok = await verifyUrl(story.sourceUrl);
      return { story, ok };
    }),
  );

  for (const { story, ok } of results) {
    if (ok) {
      verified.push(story);
    } else {
      console.log(`[fetch] Dropped story with unverifiable URL: ${story.sourceUrl}`);
    }
  }

  return verified;
}
