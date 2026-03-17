import Link from 'next/link';
import { headers } from 'next/headers';
import { notFound } from 'next/navigation';
import { Fragment } from 'react';
import { getSkillBySlug, getSkillDocument } from '@/lib/skill-store';

export const dynamic = 'force-dynamic';

const reviewLabel = {
  not_medically_reviewed: 'Not medically reviewed',
  clinician_reviewed: 'Clinician reviewed',
  not_applicable: 'Not applicable',
};

const tierLabel = {
  community: 'Community',
  verified: 'Verified',
  clinician_reviewed: 'Clinician-reviewed tier',
};

function stripFrontmatter(markdown) {
  return String(markdown || '')
    .replace(/^---\n[\s\S]*?\n---\n?/u, '')
    .trim();
}

function renderInline(text, keyPrefix) {
  return String(text || '')
    .split(/(`[^`]+`)/g)
    .filter(Boolean)
    .map((segment, index) => {
      if (segment.startsWith('`') && segment.endsWith('`')) {
        return <code key={`${keyPrefix}-code-${index}`}>{segment.slice(1, -1)}</code>;
      }

      return <Fragment key={`${keyPrefix}-text-${index}`}>{segment}</Fragment>;
    });
}

function renderMarkdownDocument(markdown) {
  const body = stripFrontmatter(markdown);
  if (!body) return null;

  const lines = body.split('\n');
  const nodes = [];
  let index = 0;
  let key = 0;

  while (index < lines.length) {
    const line = lines[index];
    const trimmed = line.trim();

    if (!trimmed) {
      index += 1;
      continue;
    }

    if (trimmed.startsWith('```')) {
      const codeLines = [];
      index += 1;
      while (index < lines.length && !lines[index].trim().startsWith('```')) {
        codeLines.push(lines[index]);
        index += 1;
      }
      index += 1;
      nodes.push(
        <pre key={`code-${key++}`} className="markdownCode">
          <code>{codeLines.join('\n')}</code>
        </pre>,
      );
      continue;
    }

    const headingMatch = trimmed.match(/^(#{1,3})\s+(.+)$/u);
    if (headingMatch) {
      const level = headingMatch[1].length;
      const title = headingMatch[2];
      const HeadingTag = level === 1 ? 'h2' : level === 2 ? 'h3' : 'h4';
      nodes.push(
        <HeadingTag key={`heading-${key++}`}>{renderInline(title, `heading-${key}`)}</HeadingTag>,
      );
      index += 1;
      continue;
    }

    if (/^- /u.test(trimmed)) {
      const items = [];
      while (index < lines.length && /^- /u.test(lines[index].trim())) {
        items.push(lines[index].trim().replace(/^- /u, ''));
        index += 1;
      }
      nodes.push(
        <ul key={`list-${key++}`} className="markdownList">
          {items.map((item, itemIndex) => (
            <li key={`item-${key}-${itemIndex}`}>{renderInline(item, `item-${key}-${itemIndex}`)}</li>
          ))}
        </ul>,
      );
      continue;
    }

    const paragraph = [];
    while (index < lines.length) {
      const current = lines[index].trim();
      if (!current || current.startsWith('```') || /^#{1,3}\s+/u.test(current) || /^- /u.test(current)) {
        break;
      }
      paragraph.push(current);
      index += 1;
    }

    nodes.push(
      <p key={`paragraph-${key++}`}>{renderInline(paragraph.join(' '), `paragraph-${key}`)}</p>,
    );
  }

  return nodes;
}

export default async function SkillPage({ params }) {
  const resolvedParams = await Promise.resolve(params || {});
  const { slug } = resolvedParams;
  const headerStore = await headers();
  const host = headerStore.get('x-forwarded-host') || headerStore.get('host') || 'skills.eir.space';
  const protocol = headerStore.get('x-forwarded-proto') || (host.includes('localhost') || host.startsWith('127.0.0.1') ? 'http' : 'https');
  let skill = null;
  let skillDocument = null;
  try {
    skill = await getSkillBySlug(slug);
    if (skill) {
      skillDocument = await getSkillDocument(skill);
    }
  } catch (error) {
    console.error('Failed to load skill detail:', error?.message || error);
  }

  if (!skill) notFound();

  const sourceCount = skill.sourceUrls?.length || 0;
  const installSnippet = `npx @eir-space/skills add Eir-Space/eir-open --skill ${skill.name}
repo: ${skill.repoUrl}
skill_path: ${skill.skillPath}`;
  const hostedMarkdownUrl = `${protocol}://${host}/skills/${skill.slug}/skill.md`;
  const curlSnippet = `curl -fsSL ${hostedMarkdownUrl} -o SKILL.md`;
  const highlights = [
    skill.healthMdCompatible
      ? 'Compatible with health.md-aware workflows.'
      : 'Does not require health.md to be useful.',
    skill.createsLinkedFile
      ? `Declares linked files: ${(skill.linkedFileNames || []).join(', ')}.`
      : 'No linked file contract is declared.',
    skillDocument
      ? skillDocument.source === 'local'
        ? 'A local SKILL.md is rendered directly on this page.'
        : 'SKILL.md is fetched from the linked GitHub repository.'
      : `${sourceCount} source link(s) are attached to this record.`,
    `Current moderation tier: ${tierLabel[skill.moderationTier] || skill.moderationTier}.`,
  ];

  return (
    <main className="pageWrap">
      <Link href="/" className="backLink">
        ← Back to directory
      </Link>

      <section className="detailHero">
        <div>
          <p className="eyebrow">@{skill.owner}</p>
          <h1>{skill.title}</h1>
          <p className="lede">{skill.summary}</p>
          <div className="commandBar detailCommandBar">
            <span className="commandLabel">Install</span>
            <code>{`npx @eir-space/skills add Eir-Space/eir-open --skill ${skill.name}`}</code>
          </div>
          <div className="pillRow">
            <span className={`pill tier ${skill.moderationTier}`}>
              {tierLabel[skill.moderationTier]}
            </span>
            <span className={`pill review ${skill.reviewStatus}`}>
              {reviewLabel[skill.reviewStatus]}
            </span>
            {skill.healthMdCompatible ? <span className="pill soft">Health.md compatible</span> : null}
            {skill.createsLinkedFile ? (
              <span className="pill soft">Creates {skill.linkedFileNames?.join(', ')}</span>
            ) : null}
          </div>
        </div>
        <div className="detailActions">
          <a href={skill.repoUrl} className="button solid" target="_blank" rel="noreferrer">
            Open GitHub Repo
          </a>
          <Link href="/submit" className="button ghost">
            Submit Update
          </Link>
        </div>
      </section>

      <section className="detailGrid">
        <div className="panel">
          <h2>Registry Metadata</h2>
          <dl className="kvList">
            <div>
              <dt>Skill name</dt>
              <dd>
                <code>{skill.name}</code>
              </dd>
            </div>
            <div>
              <dt>Skill path</dt>
              <dd>
                <code>{skill.skillPath}</code>
              </dd>
            </div>
            <div>
              <dt>Version</dt>
              <dd>{skill.version}</dd>
            </div>
            <div>
              <dt>Last reviewed</dt>
              <dd>{skill.lastReviewed || 'Not provided'}</dd>
            </div>
            <div>
              <dt>Populations</dt>
              <dd>{(skill.populations || []).join(', ') || 'Not specified'}</dd>
            </div>
            <div>
              <dt>Regions</dt>
              <dd>{(skill.regions || []).join(', ') || 'Not specified'}</dd>
            </div>
            <div>
              <dt>Status</dt>
              <dd>{skill.status}</dd>
            </div>
          </dl>
        </div>

        <div className="panel">
          <h2>Capability Signals</h2>
          <ul className="detailList">
            {highlights.map((item) => (
              <li key={item}>{item}</li>
            ))}
          </ul>
        </div>

        <div className="panel">
          <h2>Badges & Trust Signals</h2>
          <div className="pillRow">
            {(skill.badges || []).map((badge) => (
              <span key={badge} className="pill soft">
                {badge}
              </span>
            ))}
          </div>
          <p className="muted">
            This registry preserves review state, moderation tier, source links, and repo metadata
            so submissions can publish fast without losing context.
          </p>
        </div>

        {skill.sourceUrls?.length ? (
          <div className="panel">
            <h2>Source URLs</h2>
            <ul className="linksList">
              {skill.sourceUrls.map((url) => (
                <li key={url}>
                  <a href={url} target="_blank" rel="noreferrer">
                    {url}
                  </a>
                </li>
              ))}
            </ul>
          </div>
        ) : null}

        <div className="panel">
          <h2>Install / Use</h2>
          <p className="muted">
            This registry is repo-first. Submit or update by pointing to a GitHub repo and skill
            path, similar to general skill directories.
          </p>
          <pre className="codeBlock">{installSnippet}</pre>
          {skillDocument ? (
            <>
              <p className="muted installNote">
                You can also fetch the hosted markdown directly and install from the file.
              </p>
              <pre className="codeBlock">{curlSnippet}</pre>
              <a href={hostedMarkdownUrl} className="inlineLink" target="_blank" rel="noreferrer">
                Open hosted SKILL.md
              </a>
            </>
          ) : null}
        </div>

        {skillDocument ? (
          <div className="panel markdownPanel">
            <div className="markdownMeta">
              <div>
                <h2>SKILL.md</h2>
                <p className="muted">
                  {skillDocument.source === 'local'
                    ? 'Rendered directly from the local skill file used by this registry.'
                    : 'Fetched from the linked GitHub repository for this skill.'}
                </p>
              </div>
              <code>{skillDocument.path}</code>
            </div>
            <div className="markdownBody">{renderMarkdownDocument(skillDocument.markdown)}</div>
          </div>
        ) : null}
      </section>
    </main>
  );
}
