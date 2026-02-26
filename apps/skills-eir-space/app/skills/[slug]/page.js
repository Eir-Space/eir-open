import Link from "next/link";
import { notFound } from "next/navigation";
import { getSkillBySlug } from "@/lib/skill-store";

export const dynamic = "force-dynamic";

const reviewLabel = {
  not_medically_reviewed: "Not medically reviewed",
  clinician_reviewed: "Clinician reviewed",
  not_applicable: "Not applicable"
};

const tierLabel = {
  community: "Community",
  verified: "Verified",
  clinician_reviewed: "Clinician-reviewed tier"
};

export default async function SkillPage({ params }) {
  const resolvedParams = await Promise.resolve(params || {});
  const { slug } = resolvedParams;
  let skill = null;
  try {
    skill = await getSkillBySlug(slug);
  } catch (error) {
    console.error("Failed to load skill detail:", error?.message || error);
  }
  if (!skill) notFound();

  return (
    <main className="pageWrap">
      <section className="detailHero">
        <div>
          <p className="eyebrow">@{skill.owner}</p>
          <h1>{skill.title}</h1>
          <p className="lede">{skill.summary}</p>
          <div className="pillRow">
            <span className={`pill tier ${skill.moderationTier}`}>{tierLabel[skill.moderationTier]}</span>
            <span className={`pill review ${skill.reviewStatus}`}>{reviewLabel[skill.reviewStatus]}</span>
            {skill.healthMdCompatible ? <span className="pill soft">Health.md compatible</span> : null}
            {skill.createsLinkedFile ? <span className="pill soft">Creates {skill.linkedFileNames?.join(", ")}</span> : null}
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
              <dd><code>{skill.name}</code></dd>
            </div>
            <div>
              <dt>Skill path</dt>
              <dd><code>{skill.skillPath}</code></dd>
            </div>
            <div>
              <dt>Version</dt>
              <dd>{skill.version}</dd>
            </div>
            <div>
              <dt>Last reviewed</dt>
              <dd>{skill.lastReviewed || "Not provided"}</dd>
            </div>
            <div>
              <dt>Populations</dt>
              <dd>{(skill.populations || []).join(", ") || "Not specified"}</dd>
            </div>
            <div>
              <dt>Regions</dt>
              <dd>{(skill.regions || []).join(", ") || "Not specified"}</dd>
            </div>
            <div>
              <dt>Status</dt>
              <dd>{skill.status}</dd>
            </div>
          </dl>
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
            Health skills should clearly disclose review status and source links. This registry uses moderation tiers to separate fast community publishing from higher-trust reviewed listings.
          </p>
        </div>

        <div className="panel">
          <h2>Source URLs</h2>
          {skill.sourceUrls?.length ? (
            <ul className="linksList">
              {skill.sourceUrls.map((url) => (
                <li key={url}>
                  <a href={url} target="_blank" rel="noreferrer">
                    {url}
                  </a>
                </li>
              ))}
            </ul>
          ) : (
            <p className="muted">No source URLs listed for this skill.</p>
          )}
        </div>

        <div className="panel">
          <h2>Install / Use</h2>
          <p className="muted">
            This registry is repo-first. Submit or update by pointing to a GitHub repo and skill path, similar to general skill directories.
          </p>
          <pre className="codeBlock">
{`# Example (generic)
# install from repo path if your agent runtime supports repo-based skills
repo: ${skill.repoUrl}
skill_path: ${skill.skillPath}`}
          </pre>
        </div>
      </section>
    </main>
  );
}
