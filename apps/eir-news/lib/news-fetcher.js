import OpenAI from 'openai';

// ── Search queries used by Google News RSS and OpenAI web search ──

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

async function structureWithLLM(rawArticles, existingStories) {
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
    model: 'gpt-5.4',
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
  const client = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

  // Phase 1: Discover articles from real sources (parallel)
  console.log('[fetch] Discovering articles from Google News RSS and PubMed...');
  const [rssArticles, pubmedArticles] = await Promise.all([
    discoverFromGoogleNews(),
    discoverFromPubmed(),
  ]);
  console.log(`[fetch] Found ${rssArticles.length} RSS + ${pubmedArticles.length} PubMed articles`);

  // Phase 2: Also run OpenAI web search for supplementary discovery
  console.log('[fetch] Running OpenAI web search for additional stories...');
  const queries = pickQueries(3);
  let webSearchStories = [];
  try {
    const response = await client.responses.create({
      model: 'gpt-5.4',
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
  const candidates = uniqueArticles.slice(0, 20);
  console.log('[fetch] Structuring articles with gpt-5.4...');
  const structured = await structureWithLLM(candidates, existingStories);
  console.log(`[fetch] LLM produced ${structured.length} structured stories`);

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
