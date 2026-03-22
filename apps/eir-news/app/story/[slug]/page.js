import Link from 'next/link';
import { getStoryBySlug, readStories } from '@/lib/story-store';
import { notFound } from 'next/navigation';

export const dynamic = 'force-dynamic';

function formatDate(iso) {
  return new Date(iso).toLocaleDateString('en-US', {
    weekday: 'long',
    month: 'long',
    day: 'numeric',
    year: 'numeric',
  });
}

function markdownToHtml(md) {
  // Simple markdown-to-HTML for paragraphs, bold, italic, links
  return md
    .split('\n\n')
    .map((para) => {
      let html = para
        .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
        .replace(/\*(.+?)\*/g, '<em>$1</em>')
        .replace(/\[(.+?)\]\((.+?)\)/g, '<a href="$2" target="_blank" rel="noreferrer">$1</a>');
      return `<p>${html}</p>`;
    })
    .join('\n');
}

export async function generateMetadata({ params }) {
  const { slug } = await Promise.resolve(params);
  const story = getStoryBySlug(slug);
  if (!story) return { title: 'Story not found' };
  return {
    title: `${story.title} — news.eir.space`,
    description: story.summary,
  };
}

export default async function StoryPage({ params }) {
  const { slug } = await Promise.resolve(params);
  const story = getStoryBySlug(slug);
  if (!story) notFound();

  const allStories = readStories()
    .filter((s) => s.slug !== slug)
    .sort((a, b) => new Date(b.publishedAt) - new Date(a.publishedAt));

  const related = allStories
    .filter((s) => s.category === story.category || (s.tags || []).some((t) => (story.tags || []).includes(t)))
    .slice(0, 3);

  return (
    <article className="storyArticle">
      <div className="storyHeader">
        <Link href="/" className="backLink">
          All stories
        </Link>
        <div className="storyMeta">
          <span className={`categoryBadge ${story.category}`}>{story.category}</span>
          <time>{formatDate(story.publishedAt)}</time>
        </div>
        <h1>{story.title}</h1>
        <p className="storySummary">{story.summary}</p>
        <div className="storySource">
          Source:{' '}
          <a href={story.sourceUrl} target="_blank" rel="noreferrer">
            {story.source}
          </a>
        </div>
        <div className="tagRow">
          {(story.tags || []).map((t) => (
            <Link key={t} href={`/?tag=${encodeURIComponent(t)}`} className="tag clickable">
              {t}
            </Link>
          ))}
        </div>
      </div>

      <div className="storyBody" dangerouslySetInnerHTML={{ __html: markdownToHtml(story.body) }} />

      <div className="storyFooter">
        <p className="aiDisclaimer">
          This story was discovered and structured by an AI system. Always verify critical
          information with the{' '}
          <a href={story.sourceUrl} target="_blank" rel="noreferrer">
            original source
          </a>
          .
        </p>
        <p className="fetchedAt">Last updated: {formatDate(story.fetchedAt)}</p>
      </div>

      {related.length > 0 ? (
        <section className="relatedStories">
          <h2>Related stories</h2>
          <div className="relatedGrid">
            {related.map((r) => (
              <Link key={r.slug} href={`/story/${r.slug}`} className="relatedCard">
                <span className={`categoryBadge small ${r.category}`}>{r.category}</span>
                <h3>{r.title}</h3>
                <p>{r.summary}</p>
              </Link>
            ))}
          </div>
        </section>
      ) : null}
    </article>
  );
}
