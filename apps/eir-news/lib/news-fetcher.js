import OpenAI from 'openai';

// ── Search queries used by Google News RSS and OpenAI web search ──

const DEFAULT_PUBLISHED_AT = 'T00:00:00Z';
const MAX_STRUCTURED_CANDIDATES = 20;
const MAX_FALLBACK_STORIES = 10;
const OPENAI_QUOTA_HINT = /quota|billing|429|insufficient/i;
const DEFAULT_OPENAI_MODEL = 'gpt-5.4-mini';

const SEARCH_QUERIES = [
  'AI healthcare clinical trials',
  'artificial intelligence medical diagnosis',
  'LLM healthcare applications',
  'AI drug discovery',
  'machine learning radiology pathology',
  'AI mental health digital therapeutics',
  'healthcare AI startups funding',
  'FDA AI medical device',
  'AI electronic health records',
  'generative AI clinical decision support',
  'AI ambient scribe documentation',
  'EU AI Act healthcare',
  'AI genomics rare disease',
  'digital health AI wearables',
  'AI surgery robotics',
  'AI cancer detection screening',
];

function pickQueries(count = 4) {
  const shuffled = [...SEARCH_QUERIES].sort(() => Math.random() - 0.5);
  return shuffled.slice(0, count);
}

// ── URL verification ──

async function verifyUrl(url) {
  try {
    const res = await fetch(url, {
      method: 'HEAD',
      signal: AbortSignal.timeout(10_000),
      redirect: 'follow',
      headers: { 'User-Agent': 'EirNewsBot/1.0' },
    });
    if (res.status >= 200 && res.status < 400) return true;
    if (res.status === 403) return true; // paywall = article exists
    if (res.status === 405) {
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

// ── Google News RSS ──
// Free, no API key, returns real article URLs.

const GOOGLE_NEWS_RSS_QUERIES = [
  'AI healthcare',
  'artificial intelligence medicine',
  'AI drug discovery',
  'FDA AI medical device',
  'AI radiology',
  'LLM clinical',
  'AI cancer detection',
  'digital health AI',
];

function pickRssQueries(count = 4) {
  const shuffled = [...GOOGLE_NEWS_RSS_QUERIES].sort(() => Math.random() - 0.5);
  return shuffled.slice(0, count);
}

async function fetchGoogleNewsRss(query) {
  const url = `https://news.google.com/rss/search?q=${encodeURIComponent(query + ' when:7d')}&hl=en-US&gl=US&ceid=US:en`;
  try {
    const res = await fetch(url, {
      signal: AbortSignal.timeout(15_000),
      headers: { 'User-Agent': 'EirNewsBot/1.0' },
    });
    if (!res.ok) return [];
    const xml = await res.text();

    // Parse RSS items with regex (lightweight, no XML dep)
    const items = [];
    const itemRegex = /<item>([\s\S]*?)<\/item>/g;
    let match;
    while ((match = itemRegex.exec(xml)) !== null) {
      const block = match[1];
      const title = block.match(/<title>([\s\S]*?)<\/title>/)?.[1]?.replace(/<!\[CDATA\[(.*?)\]\]>/g, '$1') || '';
      const link = block.match(/<link>([\s\S]*?)<\/link>/)?.[1]?.trim() || '';
      const pubDate = block.match(/<pubDate>([\s\S]*?)<\/pubDate>/)?.[1]?.trim() || '';
      const source = block.match(/<source[^>]*>([\s\S]*?)<\/source>/)?.[1]?.replace(/<!\[CDATA\[(.*?)\]\]>/g, '$1') || '';
      if (title && link) {
        items.push({ title, link, pubDate, source });
      }
    }
    return items;
  } catch (err) {
    console.log(`[rss] Failed to fetch Google News for "${query}": ${err.message}`);
    return [];
  }
}

async function discoverFromGoogleNews() {
  const queries = pickRssQueries(4);
  const allItems = [];

  const results = await Promise.all(queries.map((q) => fetchGoogleNewsRss(q)));
  for (const items of results) {
    allItems.push(...items);
  }

  // Deduplicate by link
  const seen = new Set();
  return allItems.filter((item) => {
    if (seen.has(item.link)) return false;
    seen.add(item.link);
    return true;
  });
}

// ── PubMed E-utilities ──
// Free, no API key needed. Returns recent biomedical research.

const PUBMED_QUERIES = [
  'artificial intelligence clinical trial',
  'large language model healthcare',
  'machine learning diagnosis',
  'AI drug discovery',
  'deep learning medical imaging',
  'AI electronic health records',
];

function pickPubmedQueries(count = 2) {
  const shuffled = [...PUBMED_QUERIES].sort(() => Math.random() - 0.5);
  return shuffled.slice(0, count);
}

async function fetchPubmedArticles(query, maxResults = 5) {
  try {
    // Search for recent articles (last 30 days)
    const searchUrl = `https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=pubmed&term=${encodeURIComponent(query)}&retmax=${maxResults}&sort=date&datetype=edat&reldate=30&retmode=json`;
    const searchRes = await fetch(searchUrl, { signal: AbortSignal.timeout(10_000) });
    if (!searchRes.ok) return [];
    const searchData = await searchRes.json();
    const ids = searchData.esearchresult?.idlist || [];
    if (ids.length === 0) return [];

    // Fetch article summaries
    const summaryUrl = `https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi?db=pubmed&id=${ids.join(',')}&retmode=json`;
    const summaryRes = await fetch(summaryUrl, { signal: AbortSignal.timeout(10_000) });
    if (!summaryRes.ok) return [];
    const summaryData = await summaryRes.json();

    const articles = [];
    for (const id of ids) {
      const article = summaryData.result?.[id];
      if (!article) continue;
      const title = article.title || '';
      const source = article.fulljournalname || article.source || '';
      const pubDate = article.pubdate || '';
      const doi = (article.articleids || []).find((a) => a.idtype === 'doi')?.value;
      const link = doi
        ? `https://doi.org/${doi}`
        : `https://pubmed.ncbi.nlm.nih.gov/${id}/`;
      articles.push({ title, link, pubDate, source, pmid: id });
    }
    return articles;
  } catch (err) {
    console.log(`[pubmed] Failed to fetch for "${query}": ${err.message}`);
    return [];
  }
}

async function discoverFromPubmed() {
  const queries = pickPubmedQueries(2);
  const allArticles = [];

  const results = await Promise.all(queries.map((q) => fetchPubmedArticles(q)));
  for (const articles of results) {
    allArticles.push(...articles);
  }

  // Deduplicate by PMID
  const seen = new Set();
  return allArticles.filter((a) => {
    if (seen.has(a.pmid)) return false;
    seen.add(a.pmid);
    return true;
  });
}

// ── LLM structuring ──
// Takes raw article metadata from RSS/PubMed and asks gpt-5.4 to write structured stories.

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

function hasOpenAiKey() {
  return Boolean(process.env.OPENAI_API_KEY);
}

function openAiModelFor(task) {
  if (task === 'web-search') {
    return process.env.OPENAI_WEB_SEARCH_MODEL || process.env.OPENAI_MODEL || DEFAULT_OPENAI_MODEL;
  }
  return process.env.OPENAI_STRUCTURING_MODEL || process.env.OPENAI_MODEL || DEFAULT_OPENAI_MODEL;
}

function isWebSearchEnabled() {
  return process.env.ENABLE_OPENAI_WEB_SEARCH === 'true';
}

function sourceHostname(url) {
  try {
    return new URL(url).hostname.replace(/^www\./, '');
  } catch {
    return 'Unknown source';
  }
}

function decodeEntities(text = '') {
  return text
    .replace(/&amp;/g, '&')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&nbsp;/g, ' ')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>');
}

function normalizeTitle(title = '') {
  return decodeEntities(title)
    .replace(/\s+-\s+Google News$/, '')
    .replace(/\s+/g, ' ')
    .trim();
}

function slugify(text = '') {
  const base = text
    .toLowerCase()
    .replace(/['’"]/g, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
  return base || `story-${Date.now()}`;
}

function normalizePublishedAt(pubDate) {
  if (!pubDate) return `${new Date().toISOString().split('T')[0]}${DEFAULT_PUBLISHED_AT}`;
  const parsed = new Date(pubDate);
  if (!Number.isNaN(parsed.getTime())) return parsed.toISOString();

  const fallback = new Date(`${String(pubDate).trim()}${DEFAULT_PUBLISHED_AT}`);
  if (!Number.isNaN(fallback.getTime())) return fallback.toISOString();

  return `${new Date().toISOString().split('T')[0]}${DEFAULT_PUBLISHED_AT}`;
}

function inferCategory(article) {
  const haystack = `${article.title} ${article.source} ${article.link}`.toLowerCase();

  if (/(fda|ema|regulat|policy|law|act|compliance|approval)/.test(haystack)) return 'regulation';
  if (/(funding|raise|startup|acquire|market|invest|ceo|company)/.test(haystack)) return 'industry';
  if (/(study|research|journal|pubmed|benchmark|dataset|paper|preprint)/.test(haystack)) return 'research';
  if (/(trial|patient|hospital|clinic|therap|diagnos|screen|care|nurse|doctor)/.test(haystack)) return 'clinical';
  if (/(robot|platform|model|llm|software|device|wearable|sensor)/.test(haystack)) return 'technology';
  return 'opinion';
}

function inferTags(article, category) {
  const haystack = `${article.title} ${article.source}`.toLowerCase();
  const tagRules = [
    ['llms', /(llm|large language model|gpt|chatbot)/],
    ['drug-discovery', /(drug|molecule|chemistry|pharma|therapeutic)/],
    ['radiology', /(radiology|imaging|x-ray|ct|mri)/],
    ['regulation', /(fda|ema|regulat|policy|act)/],
    ['mental-health', /(mental health|depression|anxiety|therapy)/],
    ['clinical-trials', /(clinical trial|randomized|rct|patient study)/],
    ['medical-devices', /(device|sensor|wearable)/],
    ['diagnostics', /(diagnos|screening|detection)/],
    ['research', /(study|research|journal|pubmed|paper)/],
    ['industry', /(funding|startup|company|invest)/],
  ];

  const tags = [];
  for (const [tag, pattern] of tagRules) {
    if (pattern.test(haystack)) tags.push(tag);
  }
  if (tags.length === 0) tags.push(category);
  return tags.slice(0, 4);
}

function trimSourceFromTitle(title, source) {
  if (!source) return title;

  const escapedSource = source.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  return title
    .replace(new RegExp(`\\s+-\\s+${escapedSource}$`, 'i'), '')
    .replace(new RegExp(`\\s+\\|\\s+${escapedSource}$`, 'i'), '')
    .trim();
}

function formatSourceDate(article) {
  const publishedAt = normalizePublishedAt(article.pubDate);
  return publishedAt.slice(0, 10);
}

function categoryAngle(category, title) {
  const lower = title.toLowerCase();

  if (category === 'regulation') {
    return 'It matters because regulatory signals often determine how quickly healthcare AI can move from pilot projects into routine use.';
  }
  if (category === 'industry') {
    return 'It matters because capital allocation and go-to-market decisions shape which healthcare AI products actually reach clinics and health systems.';
  }
  if (category === 'research') {
    return 'It matters because new evidence, benchmarks, and validation studies often reveal whether healthcare AI claims are translating into credible science.';
  }
  if (category === 'clinical') {
    return 'It matters because the clinical value of healthcare AI depends on whether it can improve workflows, detection, or outcomes in real patient settings.';
  }
  if (category === 'technology') {
    return 'It matters because infrastructure and model advances often determine what is feasible for the next wave of healthcare applications.';
  }
  if (/funding|raise|startup|investment/.test(lower)) {
    return 'It matters because investor appetite remains a practical signal of where operators believe defensible value is emerging.';
  }
  return 'It matters because the headline points to where expectations around healthcare AI are expanding faster than the supporting evidence.';
}

function buildFallbackSummary(article, category) {
  const source = article.source || sourceHostname(article.link);
  const title = trimSourceFromTitle(normalizeTitle(article.title), source);
  return `${source} reports on ${title}. ${categoryAngle(category, title)}`;
}

function buildFallbackBody(article, category) {
  const source = article.source || sourceHostname(article.link);
  const title = trimSourceFromTitle(normalizeTitle(article.title), source);
  const publishedDate = formatSourceDate(article);

  return [
    `${source} published "${title}" on ${publishedDate}. This brief highlights the core development surfaced by the source and keeps the focus on what appears to matter most for healthcare AI.`,
    `${categoryAngle(category, title)} The headline suggests this is most relevant as ${category} coverage, which is why it has been grouped with similar stories on the site.`,
    `Readers should treat this as a quick briefing and follow the source link for the full reporting, methods, and limitations in the original piece.`,
  ].join('\n\n');
}

function buildFallbackStories(rawArticles, existingStories = []) {
  const now = new Date().toISOString();
  const existingSlugs = new Set(existingStories.map((story) => story.slug));
  const stories = [];

  for (const article of rawArticles) {
    const source = article.source || sourceHostname(article.link);
    const title = trimSourceFromTitle(normalizeTitle(article.title), source);
    if (!title || !article.link) continue;

    const category = inferCategory(article);
    let slug = slugify(title);
    let suffix = 2;
    while (existingSlugs.has(slug) || stories.some((story) => story.slug === slug)) {
      slug = `${slugify(title)}-${suffix}`;
      suffix += 1;
    }
    existingSlugs.add(slug);

    stories.push({
      id: slug,
      title,
      slug,
      summary: buildFallbackSummary(article, category),
      body: buildFallbackBody(article, category),
      category,
      tags: inferTags(article, category),
      source,
      sourceUrl: article.link,
      publishedAt: normalizePublishedAt(article.pubDate),
      fetchedAt: now,
    });

    if (stories.length >= MAX_FALLBACK_STORIES) break;
  }

  return stories;
}

async function structureWithLLM(rawArticles, existingStories, model = openAiModelFor('structuring')) {
  if (rawArticles.length === 0) return [];

  const client = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

  const existingContext =
    existingStories.length > 0
      ? `\nALREADY PUBLISHED (skip these):\n${existingStories
          .slice(0, 50)
          .map((s) => `- "${s.title}"`)
          .join('\n')}\n`
      : '';

  const articlesContext = rawArticles
    .map(
      (a, i) =>
        `${i + 1}. "${a.title}" — ${a.source} (${a.pubDate || 'recent'})\n   URL: ${a.link}`,
    )
    .join('\n');

  const response = await client.responses.create({
    model,
    input: `You are a healthcare AI news editor. Below are real articles discovered from news feeds and research databases. Pick the 6-10 most significant and interesting ones and write structured news stories about them.

DISCOVERED ARTICLES:
${articlesContext}
${existingContext}
For each article you select, create a story object with:
- "title": compelling headline (string)
- "slug": URL-friendly slug (lowercase, hyphens, no special chars)
- "summary": 2-3 sentence summary (string)
- "body": 3-5 paragraph analytical article in markdown (string). Write insightful analysis, not just a rewrite.
- "category": one of "clinical", "research", "regulation", "industry", "technology", "opinion"
- "tags": array of relevant tags
- "source": publication name from the discovered article (string)
- "sourceUrl": the EXACT URL from the discovered article — do NOT change or guess URLs (string)
- "publishedAt": ISO date from the article, or "${new Date().toISOString().split('T')[0]}" if unknown
- "fetchedAt": "${new Date().toISOString()}"

IMPORTANT:
- Use ONLY the URLs provided above. Do NOT make up or modify any URL.
- Skip articles that are duplicates of already published stories.
- Return ONLY a valid JSON array. No markdown fences, no preamble.`,
  });

  const text = response.output_text;
  if (!text) throw new Error('No text response from LLM');
  return parseStories(text);
}

// ── Main fetch pipeline ──

/**
 * Fetch news from multiple sources, structure with LLM, verify URLs, deduplicate.
 *
 * Pipeline:
 *   1. Google News RSS → real article URLs
 *   2. PubMed E-utilities → recent research papers
 *   3. OpenAI web search → supplementary discovery
 *   4. LLM structures all discovered articles into stories
 *   5. URL verification drops dead links
 *   6. Deduplication against existing stories
 */
export async function fetchWithWebSearch(existingStories = []) {
  const openAiConfigured = hasOpenAiKey();
  const client = openAiConfigured ? new OpenAI({ apiKey: process.env.OPENAI_API_KEY }) : null;
  const structuringModel = openAiModelFor('structuring');
  const webSearchModel = openAiModelFor('web-search');
  const webSearchEnabled = isWebSearchEnabled();

  // Phase 1: Discover articles from real sources (parallel)
  console.log('[fetch] Discovering articles from Google News RSS and PubMed...');
  const [rssArticles, pubmedArticles] = await Promise.all([
    discoverFromGoogleNews(),
    discoverFromPubmed(),
  ]);
  console.log(`[fetch] Found ${rssArticles.length} RSS + ${pubmedArticles.length} PubMed articles`);

  // Phase 2: Also run OpenAI web search for supplementary discovery
  const queries = pickQueries(3);
  let webSearchStories = [];
  if (client && webSearchEnabled) {
    console.log(`[fetch] Running OpenAI web search with ${webSearchModel} for additional stories...`);
    try {
      const response = await client.responses.create({
        model: webSearchModel,
        tools: [{ type: 'web_search_preview' }],
        input: `Search the web for the latest significant news about AI in healthcare from the past week. Focus on:

${queries.map((q, i) => `${i + 1}. ${q}`).join('\n')}

For each article you find, return a JSON array of objects with:
- "title": article headline
- "link": the exact article URL
- "source": publication name
- "pubDate": publication date

Return ONLY a JSON array. No other text.

Today: ${new Date().toISOString().split('T')[0]}`,
      });
      const text = response.output_text?.trim();
      if (text) {
        const jsonStr = text.startsWith('[') ? text : text.match(/\[[\s\S]*\]/)?.[0];
        if (jsonStr) {
          webSearchStories = JSON.parse(jsonStr);
          console.log(`[fetch] OpenAI web search found ${webSearchStories.length} articles`);
        }
      }
    } catch (err) {
      console.log(`[fetch] OpenAI web search failed (non-fatal): ${err.message}`);
      if (OPENAI_QUOTA_HINT.test(err.message)) {
        console.log('[fetch] OpenAI web search is over quota, continuing with free sources only');
      }
    }
  } else if (client) {
    console.log('[fetch] OpenAI web search is disabled, using RSS and PubMed only');
  } else {
    console.log('[fetch] OPENAI_API_KEY is missing, skipping web search');
  }

  // Phase 3: Combine all discovered articles
  const allArticles = [
    ...rssArticles.map((a) => ({ ...a, via: 'rss' })),
    ...pubmedArticles.map((a) => ({ ...a, via: 'pubmed' })),
    ...webSearchStories.map((a) => ({ ...a, via: 'websearch' })),
  ];

  // Deduplicate by URL
  const seenUrls = new Set(existingStories.map((s) => s.sourceUrl));
  const uniqueArticles = allArticles.filter((a) => {
    if (seenUrls.has(a.link)) return false;
    seenUrls.add(a.link);
    return true;
  });

  console.log(`[fetch] ${uniqueArticles.length} unique new articles after dedup`);
  if (uniqueArticles.length === 0) return [];

  // Phase 4: Structure top articles with LLM
  // Limit to 20 most interesting candidates to avoid token waste
  const candidates = uniqueArticles.slice(0, MAX_STRUCTURED_CANDIDATES);
  let structured = [];
  if (openAiConfigured) {
    console.log(`[fetch] Structuring articles with ${structuringModel}...`);
    try {
      structured = await structureWithLLM(candidates, existingStories, structuringModel);
      console.log(`[fetch] LLM produced ${structured.length} structured stories`);
    } catch (err) {
      console.log(`[fetch] LLM structuring failed, switching to fallback stories: ${err.message}`);
      structured = buildFallbackStories(candidates, existingStories);
    }
  } else {
    console.log('[fetch] OPENAI_API_KEY is missing, using fallback story generation');
    structured = buildFallbackStories(candidates, existingStories);
  }

  // Phase 5: Deduplicate structured stories against existing
  const existingSlugs = new Set(existingStories.map((s) => s.slug));
  const existingUrlSet = new Set(existingStories.map((s) => s.sourceUrl));
  const fresh = structured.filter(
    (s) => !existingSlugs.has(s.slug) && !existingUrlSet.has(s.sourceUrl),
  );

  // Phase 6: Verify URLs in parallel
  console.log(`[fetch] Verifying ${fresh.length} URLs...`);
  const verifyResults = await Promise.all(
    fresh.map(async (story) => {
      const ok = await verifyUrl(story.sourceUrl);
      return { story, ok };
    }),
  );

  const verified = [];
  for (const { story, ok } of verifyResults) {
    if (ok) {
      verified.push(story);
    } else {
      console.log(`[fetch] Dropped unverifiable URL: ${story.sourceUrl}`);
    }
  }

  console.log(`[fetch] ${verified.length} verified stories ready to publish`);
  return verified;
}
