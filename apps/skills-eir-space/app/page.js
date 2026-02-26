import Link from "next/link";
import { SkillCard } from "@/components/skill-card";
import { getFilterOptions, listSkills, readStore } from "@/lib/skill-store";

export const dynamic = "force-dynamic";

function uniqueTags(skills) {
  return [...new Set(skills.flatMap((s) => s.domainTags || []))].sort();
}

function statCards(skills, submissions) {
  const pending = submissions.filter((s) => s.status === "queued").length;
  const clinician = skills.filter((s) => s.moderationTier === "clinician_reviewed").length;
  const linkedFiles = skills.filter((s) => s.createsLinkedFile).length;
  return [
    { label: "Published health skills", value: String(skills.length).padStart(2, "0") },
    { label: "Queued submissions", value: String(pending).padStart(2, "0") },
    { label: "Skills with linked files", value: String(linkedFiles).padStart(2, "0") },
    { label: "Clinician-reviewed tier", value: String(clinician).padStart(2, "0") }
  ];
}

export default async function HomePage({ searchParams }) {
  const params = searchParams || {};
  const q = params?.q || "";
  const tag = params?.tag || "";
  const reviewStatus = params?.review || "";
  const moderationTier = params?.tier || "";

  let skills = [];
  let store = { skills: [], submissions: [] };
  try {
    [skills, store] = await Promise.all([
      listSkills({ q, tag, reviewStatus, moderationTier }),
      readStore()
    ]);
  } catch (error) {
    console.error("Failed to load skills directory data:", error?.message || error);
  }
  const tags = uniqueTags(store.skills);
  const filters = getFilterOptions();
  const stats = statCards(store.skills, store.submissions);

  return (
    <main className="pageWrap">
      <section className="hero">
        <div className="heroBg" />
        <div className="heroInner">
          <div className="heroCopy">
            <p className="eyebrow accent">skills.eir.space</p>
            <h1>Health Skills for Agents</h1>
            <p className="lede">
              A hybrid registry for agent-compatible healthcare skills: public submissions, trust badges, moderation tiers, and `health.md` interoperability.
            </p>
            <div className="heroActions">
              <Link href="/submit" className="button solid big">
                Submit / Update Skill
              </Link>
              <a className="button ghost big" href="https://agentskill.sh/submit" target="_blank" rel="noreferrer">
                Compare with agentskill.sh
              </a>
            </div>
          </div>
          <div className="heroPanel">
            <h2>Hybrid moderation</h2>
            <ul className="checklist">
              <li>Public submissions are accepted and queued.</li>
              <li>Community tier publishes fast with clear badges.</li>
              <li>Verified and clinician-reviewed tiers can be granted later.</li>
            </ul>
            <div className="pillRow">
              <span className="pill tier community">Community</span>
              <span className="pill tier verified">Verified</span>
              <span className="pill tier clinician_reviewed">Clinician-reviewed tier</span>
            </div>
          </div>
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

      <section className="controls">
        <form className="filterBar" action="/">
          <div className="field">
            <label htmlFor="q">Search</label>
            <input id="q" name="q" defaultValue={q} placeholder="pregnancy, diabetes, triage, health.md" />
          </div>
          <div className="field">
            <label htmlFor="tag">Tag</label>
            <select id="tag" name="tag" defaultValue={tag}>
              <option value="">All tags</option>
              {tags.map((t) => (
                <option key={t} value={t}>
                  {t}
                </option>
              ))}
            </select>
          </div>
          <div className="field">
            <label htmlFor="review">Review</label>
            <select id="review" name="review" defaultValue={reviewStatus}>
              {filters.reviewStatuses.map((opt) => (
                <option key={opt.value || "all"} value={opt.value}>
                  {opt.label}
                </option>
              ))}
            </select>
          </div>
          <div className="field">
            <label htmlFor="tier">Tier</label>
            <select id="tier" name="tier" defaultValue={moderationTier}>
              {filters.moderationTiers.map((opt) => (
                <option key={opt.value || "all"} value={opt.value}>
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
          <h2>Curated Health Skill Catalog</h2>
        </div>
        <p className="muted">{skills.length} visible result(s)</p>
      </section>

      <section className="gridCards">
        {skills.map((skill) => (
          <SkillCard key={skill.id} skill={skill} />
        ))}
      </section>

      <section className="howItWorks">
        <div className="panel">
          <h3>How this differs from general skill directories</h3>
          <p>
            `skills.eir.space` is health-focused. Skills can declare review status, source URLs, `health.md` compatibility, linked file patterns like `pregnancy.md`, and moderation tier badges.
          </p>
        </div>
        <div className="panel">
          <h3>How `skills.sh` / `agentskill.sh` works (high-level)</h3>
          <p>
            It indexes skills from GitHub repos and `SKILL.md` files, accepts submissions via a web form, and ranks discoverability partly from install telemetry. This app mirrors that repo-based submission model but adds healthcare trust metadata and moderation tiers.
          </p>
        </div>
      </section>
    </main>
  );
}
