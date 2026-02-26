import Link from "next/link";

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

export function SkillCard({ skill }) {
  return (
    <article className="skillCard">
      <div className="skillCardTop">
        <div>
          <p className="eyebrow">@{skill.owner}</p>
          <h3>{skill.title}</h3>
          <p className="skillSlug">{skill.name}</p>
        </div>
        <div className="stackBadges">
          <span className={`pill tier ${skill.moderationTier}`}>{tierLabel[skill.moderationTier] || skill.moderationTier}</span>
          <span className={`pill review ${skill.reviewStatus}`}>{reviewLabel[skill.reviewStatus] || skill.reviewStatus}</span>
        </div>
      </div>

      <p className="summary">{skill.summary}</p>

      <div className="metaRow">
        <div className="metaBlock">
          <span className="metaLabel">Tags</span>
          <div className="pillRow">
            {(skill.domainTags || []).slice(0, 4).map((tag) => (
              <span key={tag} className="pill soft">
                {tag}
              </span>
            ))}
          </div>
        </div>
      </div>

      <div className="metaRow compact">
        <span>{skill.healthMdCompatible ? "Health.md compatible" : "No Health.md contract"}</span>
        <span>{skill.createsLinkedFile ? `Creates ${skill.linkedFileNames?.join(", ")}` : "No linked file"}</span>
      </div>

      <div className="cardFooter">
        <Link href={`/skills/${skill.slug}`} className="button ghost">
          View Skill
        </Link>
        <a href={skill.repoUrl} target="_blank" rel="noreferrer" className="button solid">
          GitHub
        </a>
      </div>
    </article>
  );
}
