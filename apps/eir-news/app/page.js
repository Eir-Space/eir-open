import Link from 'next/link';
import { readStories, getCategories } from '@/lib/story-store';
import { StoryCard } from '@/components/story-card';

export const dynamic = 'force-dynamic';

function formatDate(iso) {
  return new Date(iso).toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  });
}

export default async function HomePage({ searchParams }) {
  const params = await Promise.resolve(searchParams || {});
  const category = params?.category || '';
  const tag = params?.tag || '';

  let stories = readStories();
  const categories = getCategories();

  if (category) {
    stories = stories.filter((s) => s.category === category);
  }
  if (tag) {
    stories = stories.filter((s) => (s.tags || []).includes(tag));
  }

  // Sort by publishedAt descending
  stories.sort((a, b) => new Date(b.publishedAt) - new Date(a.publishedAt));

  const featured = stories[0];
  const rest = stories.slice(1);

  return (
    <>
      <section className="heroSection">
        <div className="heroContent">
          <p className="eyebrow accent">AI in Healthcare</p>
          <h1>The latest on artificial intelligence transforming medicine</h1>
          <p className="lede">
            News stories discovered and organized by an automated pipeline. Covering clinical
            deployments, research breakthroughs, regulation, and industry developments.
          </p>
        </div>
      </section>

      {category || tag ? (
        <section className="filterActive">
          <span className="filterLabel">
            Filtered by: <strong>{category || tag}</strong>
          </span>
          <Link href="/" className="clearFilter">
            Clear filter
          </Link>
        </section>
      ) : null}

      {featured ? (
        <section className="featuredStory">
          <Link href={`/story/${featured.slug}`} className="featuredLink">
            <div className="featuredMeta">
              <span className={`categoryBadge ${featured.category}`}>{featured.category}</span>
              <time>{formatDate(featured.publishedAt)}</time>
              <span className="source">{featured.source}</span>
            </div>
            <h2>{featured.title}</h2>
            <p>{featured.summary}</p>
            <div className="tagRow">
              {(featured.tags || []).slice(0, 4).map((t) => (
                <span key={t} className="tag">
                  {t}
                </span>
              ))}
            </div>
          </Link>
        </section>
      ) : null}

      <section className="storyGrid">
        {rest.map((story) => (
          <StoryCard key={story.slug} story={story} />
        ))}
      </section>

      {stories.length === 0 ? (
        <section className="emptyState">
          <h3>No stories found</h3>
          <p>
            {category || tag
              ? 'Try a different filter or browse all stories.'
              : 'Stories will appear here once fetched.'}
          </p>
          <Link href="/" className="button solid">
            View all stories
          </Link>
        </section>
      ) : null}

      <section className="aboutSection">
        <h2>How this works</h2>
        <div className="aboutGrid">
          <div className="aboutCard">
            <h3>Discover</h3>
            <p>
              An automated pipeline searches the web for significant AI healthcare news across
              clinical, research, regulatory, and industry domains.
            </p>
          </div>
          <div className="aboutCard">
            <h3>Structure</h3>
            <p>
              The pipeline turns source material into concise, readable stories with categories,
              tags, and context that make the feed easier to scan.
            </p>
          </div>
          <div className="aboutCard">
            <h3>Publish</h3>
            <p>
              Stories are deduplicated, stored, and published to this site. The pipeline runs
              automatically to keep coverage current.
            </p>
          </div>
        </div>
      </section>
    </>
  );
}
