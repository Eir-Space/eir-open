import Link from 'next/link';
import { SkillCard } from '@/components/skill-card';
import { getFilterOptions, listSkills, readStore } from '@/lib/skill-store';

export const dynamic = 'force-dynamic';

function uniqueTags(skills) {
  return [...new Set(skills.flatMap((skill) => skill.domainTags || []))].sort();
}

function statCards(skills, submissions) {
  const pending = submissions.filter((submission) => submission.status === 'queued').length;
  const trusted = skills.filter((skill) => skill.moderationTier !== 'community').length;
  const medical = skills.filter((skill) =>
    (skill.domainTags || []).some((tag) =>
      ['medications', 'health-md', 'pregnancy', 'diabetes', 'therapy', 'reference'].includes(tag),
    ),
  ).length;

  return [
    { label: 'Ready to install', value: String(skills.length).padStart(2, '0') },
    { label: 'Waiting for review', value: String(pending).padStart(2, '0') },
    { label: 'Higher-trust skills', value: String(trusted).padStart(2, '0') },
    { label: 'Healthcare workflows', value: String(medical).padStart(2, '0') },
  ];
}

export default async function HomePage({ searchParams }) {
  const params = await Promise.resolve(searchParams || {});
  const q = params?.q || '';
  const tag = params?.tag || '';
  const reviewStatus = params?.review || '';
  const moderationTier = params?.tier || '';

  let skills = [];
  let store = { skills: [], submissions: [] };
  try {
    [skills, store] = await Promise.all([
      listSkills({ q, tag, reviewStatus, moderationTier }),
      readStore(),
    ]);
  } catch (error) {
    console.error('Failed to load skills directory data:', error?.message || error);
  }

  const tags = uniqueTags(store.skills);
  const filters = getFilterOptions();
  const stats = statCards(store.skills, store.submissions);
  const spotlight =
    store.skills.find((skill) => skill.slug === 'health-actions') || store.skills[0] || null;
  const agentRuntimes = [
    'Codex',
    'Claude Code',
    'Cursor',
    'Cline',
    'OpenCode',
    'Goose',
    'Gemini',
    'GitHub Copilot',
  ];
  const tracks = [
    {
      title: 'Help users take the right next step',
      description: 'Action skills turn context into specific, doable interventions instead of generic advice.',
      tag: 'health-actions',
    },
    {
      title: 'Ground agents in real health context',
      description: 'Use health records, linked files, and longitudinal context to make the agent more useful.',
      tag: 'health-md',
    },
    {
      title: 'Support safer medication work',
      description: 'Add practical medication lookup and reference workflows where precision matters.',
      tag: 'medications',
    },
  ];
  const registryBoard = [...skills]
    .slice(0, 6)
    .map((skill, index) => ({
      rank: index + 1,
      skill,
    }));

  return (
    <main className="pageWrap">
      <section className="heroStage">
        <div className="heroGrid">
          <div className="heroCopy">
            <p className="eyebrow accent">Medical agent skills from Eir</p>
            <h1>Build your medical agent with medical skills from Eir.</h1>
            <p className="lede">
              Give your agent better judgment, richer health context, and more useful next actions
              with a focused registry of installable medical skills.
            </p>
            <div className="commandBar">
              <span className="commandLabel">Install a skill</span>
              <code>npx @eir-space/skills add Eir-Space/eir-open --skill health-actions</code>
            </div>
            <div className="agentStrip">
              <span className="eyebrow">Works with</span>
              <div className="agentPills">
                {agentRuntimes.map((runtime) => (
                  <span key={runtime} className="agentPill">
                    {runtime}
                  </span>
                ))}
              </div>
            </div>
            <div className="heroActions">
              <Link href="/skills/health-actions" className="button solid big">
                Start with Health Actions
              </Link>
              <Link href="/submit" className="button ghost big">
                Submit a Skill
              </Link>
              <a
                className="button ghost big"
                href="https://github.com/Eir-Space/eir-open/tree/main/skills"
                target="_blank"
                rel="noreferrer"
              >
                Browse GitHub
              </a>
            </div>
          </div>

          {spotlight ? (
            <aside className="spotlightCard">
              <p className="eyebrow">Featured starting point</p>
              <h2>{spotlight.title}</h2>
              <p>{spotlight.summary}</p>
              <div className="pillRow">
                {(spotlight.badges || []).slice(0, 3).map((badge) => (
                  <span key={badge} className="pill soft">
                    {badge}
                  </span>
                ))}
              </div>
              <div className="heroActions compact">
                <Link href={`/skills/${spotlight.slug}`} className="button solid">
                  View Skill
                </Link>
                <a
                  href={spotlight.repoUrl}
                  target="_blank"
                  rel="noreferrer"
                  className="button ghost"
                >
                  GitHub
                </a>
              </div>
            </aside>
          ) : null}
        </div>

        <div className="statsGrid">
          {stats.map((stat) => (
            <div key={stat.label} className="statCard">
              <div className="statValue">{stat.value}</div>
              <div className="statLabel">{stat.label}</div>
            </div>
          ))}
        </div>
      </section>

      <section className="signalGrid">
        <article className="insightCard">
          <p className="eyebrow">Better outcomes</p>
          <h3>Move from generic prompting to repeatable medical behavior.</h3>
          <p>
            Skills help agents ask better questions, use better context, and make better
            suggestions without starting from scratch every time.
          </p>
        </article>
        <article className="insightCard">
          <p className="eyebrow">Trust</p>
          <h3>Show what the agent is using and why it deserves confidence.</h3>
          <p>
            Visible markdown, provenance, and review state make it easier to inspect a skill before
            you put it into a medical workflow.
          </p>
        </article>
        <article className="insightCard">
          <p className="eyebrow">Compound value</p>
          <h3>Capture a good workflow once and let every Eir agent benefit.</h3>
          <p>
            A strong skill becomes shared infrastructure for teams building safer, more helpful
            healthcare agents.
          </p>
        </article>
      </section>

      <section className="sectionHeader">
        <div>
          <p className="eyebrow">Registry Board</p>
          <h2>Start with the skills that change behavior fastest</h2>
        </div>
        <p className="muted">Minimal by design. High-signal by default.</p>
      </section>

      <section className="boardPanel">
        <div className="boardHeader">
          <span>#</span>
          <span>Skill</span>
          <span>Tier</span>
          <span>Path</span>
        </div>
        <div className="boardRows">
          {registryBoard.map(({ rank, skill }) => (
            <Link key={skill.id} href={`/skills/${skill.slug}`} className="boardRow">
              <strong>{rank}</strong>
              <span className="boardSkill">
                <b>{skill.title}</b>
                <small>
                  {skill.owner}/{skill.name}
                </small>
              </span>
              <span className={`pill tier ${skill.moderationTier}`}>
                {skill.moderationTier.replace('_', ' ')}
              </span>
              <code>{skill.skillPath}</code>
            </Link>
          ))}
        </div>
      </section>

      <section className="sectionHeader">
        <div>
          <p className="eyebrow">Collections</p>
          <h2>Choose the capability your agent needs next</h2>
        </div>
      </section>

      <section className="collectionGrid">
        {tracks.map((track) => (
          <Link key={track.title} href={`/?tag=${encodeURIComponent(track.tag)}`} className="collectionCard">
            <p className="eyebrow">{track.tag}</p>
            <h3>{track.title}</h3>
            <p>{track.description}</p>
          </Link>
        ))}
      </section>

      <section className="controls">
        <form className="filterBar" action="/">
          <div className="field">
            <label htmlFor="q">Search</label>
            <input
              id="q"
              name="q"
              defaultValue={q}
              placeholder="health-actions, medications, registry, health.md"
            />
          </div>
          <div className="field">
            <label htmlFor="tag">Tag</label>
            <select id="tag" name="tag" defaultValue={tag}>
              <option value="">All tags</option>
              {tags.map((entry) => (
                <option key={entry} value={entry}>
                  {entry}
                </option>
              ))}
            </select>
          </div>
          <div className="field">
            <label htmlFor="review">Review</label>
            <select id="review" name="review" defaultValue={reviewStatus}>
              {filters.reviewStatuses.map((opt) => (
                <option key={opt.value || 'all'} value={opt.value}>
                  {opt.label}
                </option>
              ))}
            </select>
          </div>
          <div className="field">
            <label htmlFor="tier">Tier</label>
            <select id="tier" name="tier" defaultValue={moderationTier}>
              {filters.moderationTiers.map((opt) => (
                <option key={opt.value || 'all'} value={opt.value}>
                  {opt.label}
                </option>
              ))}
            </select>
          </div>
          <button className="button solid" type="submit">
            Apply
          </button>
        </form>
      </section>

      <section className="sectionHeader">
        <div>
          <p className="eyebrow">Directory</p>
          <h2>Medical skills ready to inspect and install</h2>
        </div>
        <p className="muted">{skills.length} visible result(s)</p>
      </section>

      <section className="gridCards">
        {skills.length ? (
          skills.map((skill) => <SkillCard key={skill.id} skill={skill} />)
        ) : (
          <div className="emptyState">
            <h3>No skills matched those filters.</h3>
            <p>Try a broader search like `health-actions`, `registry`, or `health-md`.</p>
          </div>
        )}
      </section>

      <section className="ctaBand">
        <div>
          <p className="eyebrow">Contribute</p>
          <h2>Publish the workflow that makes your agent genuinely better.</h2>
          <p className="lede compact">
            If a skill saves time, improves trust, or helps people take better health actions, put
            it in the registry so it can compound across Eir.
          </p>
        </div>
        <div className="heroActions compact">
          <Link href="/submit" className="button solid">
            Submit a Skill
          </Link>
          <a
            href="https://github.com/Eir-Space/eir-open/tree/main/apps/skills-eir-cli"
            className="button ghost"
            target="_blank"
            rel="noreferrer"
          >
            View CLI
          </a>
        </div>
      </section>

    </main>
  );
}
