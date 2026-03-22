import Link from 'next/link';

function formatDate(iso) {
  return new Date(iso).toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
  });
}

export function StoryCard({ story }) {
  return (
    <Link href={`/story/${story.slug}`} className="storyCard">
      <div className="cardMeta">
        <span className={`categoryBadge small ${story.category}`}>{story.category}</span>
        <time>{formatDate(story.publishedAt)}</time>
      </div>
      <h3>{story.title}</h3>
      <p>{story.summary}</p>
      <div className="cardFooter">
        <span className="source">{story.source}</span>
        <div className="tagRow compact">
          {(story.tags || []).slice(0, 3).map((t) => (
            <span key={t} className="tag small">
              {t}
            </span>
          ))}
        </div>
      </div>
    </Link>
  );
}
