import { fetchWithWebSearch } from '@/lib/news-fetcher';
import { addStories, readStories } from '@/lib/story-store';

export async function POST(request) {
  const authHeader = request.headers.get('authorization');
  const expectedToken = process.env.FETCH_NEWS_TOKEN;

  if (expectedToken && authHeader !== `Bearer ${expectedToken}`) {
    return Response.json({ error: 'Unauthorized' }, { status: 401 });
  }

  try {
    const existing = readStories();
    const stories = await fetchWithWebSearch(existing);
    const result = addStories(stories);

    return Response.json({
      success: true,
      fetched: stories.length,
      added: result.added,
      total: result.total,
    });
  } catch (err) {
    console.error('Fetch news error:', err);
    return Response.json({ error: err.message }, { status: 500 });
  }
}

export async function GET() {
  return Response.json({
    endpoint: '/api/fetch-news',
    method: 'POST',
    description: 'Fetch and structure new AI healthcare stories using OpenAI with web search',
    auth: 'Bearer token via FETCH_NEWS_TOKEN env var (optional in dev)',
  });
}
