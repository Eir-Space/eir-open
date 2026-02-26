"use client";

import { useState, useTransition } from "react";

const initialState = {
  name: "",
  title: "",
  owner: "eir-space",
  repoUrl: "",
  skillPath: "",
  summary: "",
  domainTags: "",
  populations: "",
  regions: "global",
  reviewStatus: "not_medically_reviewed",
  lastReviewed: "",
  sourceUrls: "",
  healthMdCompatible: true,
  createsLinkedFile: false,
  linkedFileNames: "",
  version: "0.1.0",
  submitter: "",
  moderationTierRequested: "community",
  notes: ""
};

export function SubmitForm() {
  const [form, setForm] = useState(initialState);
  const [result, setResult] = useState(null);
  const [error, setError] = useState("");
  const [isPending, startTransition] = useTransition();

  function updateField(key, value) {
    setForm((prev) => ({ ...prev, [key]: value }));
  }

  async function handleSubmit(event) {
    event.preventDefault();
    setError("");
    setResult(null);

    startTransition(async () => {
      try {
        const response = await fetch("/api/submit", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(form)
        });

        const data = await response.json();
        if (!response.ok) {
          throw new Error(data?.error || "Submission failed");
        }

        setResult(data);
        setForm((prev) => ({
          ...initialState,
          owner: prev.owner || "eir-space",
          reviewStatus: prev.reviewStatus
        }));
      } catch (err) {
        setError(err.message || "Submission failed");
      }
    });
  }

  return (
    <div className="submitShell">
      <div className="submitIntro">
        <h2>Submit or Update a Health Skill</h2>
        <p>
          Hybrid model: public submissions are accepted immediately into the queue and published with community moderation by default. Higher trust badges are added after review.
        </p>
        <ul className="checklist">
          <li>Public submission: anyone can submit a GitHub repo + skill path.</li>
          <li>Badges: health.md compatibility, linked file support, source URLs, review state.</li>
          <li>Moderation tiers: community, verified, clinician-reviewed tier.</li>
        </ul>
      </div>

      <form className="submitForm" onSubmit={handleSubmit}>
        <div className="grid2">
          <label>
            Skill name
            <input value={form.name} onChange={(e) => updateField("name", e.target.value)} placeholder="pregnancy" required />
          </label>
          <label>
            Display title
            <input value={form.title} onChange={(e) => updateField("title", e.target.value)} placeholder="Pregnancy" />
          </label>
        </div>

        <div className="grid2">
          <label>
            Owner
            <input value={form.owner} onChange={(e) => updateField("owner", e.target.value)} placeholder="eir-space" />
          </label>
          <label>
            Version
            <input value={form.version} onChange={(e) => updateField("version", e.target.value)} placeholder="0.1.0" />
          </label>
        </div>

        <label>
          GitHub repo URL
          <input
            value={form.repoUrl}
            onChange={(e) => updateField("repoUrl", e.target.value)}
            placeholder="https://github.com/Eir-Space/pregnancy"
            required
          />
        </label>

        <div className="grid2">
          <label>
            Skill path
            <input value={form.skillPath} onChange={(e) => updateField("skillPath", e.target.value)} placeholder="pregnancy/" />
          </label>
          <label>
            Last reviewed (optional)
            <input value={form.lastReviewed} onChange={(e) => updateField("lastReviewed", e.target.value)} placeholder="2026-02-26" />
          </label>
        </div>

        <label>
          Summary
          <textarea
            rows={4}
            value={form.summary}
            onChange={(e) => updateField("summary", e.target.value)}
            placeholder="What this health skill does and how it grounds an agent."
            required
          />
        </label>

        <div className="grid3">
          <label>
            Domain tags (comma-separated)
            <input value={form.domainTags} onChange={(e) => updateField("domainTags", e.target.value)} placeholder="pregnancy, prenatal-care" />
          </label>
          <label>
            Populations
            <input value={form.populations} onChange={(e) => updateField("populations", e.target.value)} placeholder="pregnant" />
          </label>
          <label>
            Regions
            <input value={form.regions} onChange={(e) => updateField("regions", e.target.value)} placeholder="global" />
          </label>
        </div>

        <div className="grid2">
          <label>
            Review status
            <select value={form.reviewStatus} onChange={(e) => updateField("reviewStatus", e.target.value)}>
              <option value="not_medically_reviewed">Not medically reviewed</option>
              <option value="clinician_reviewed">Clinician reviewed</option>
              <option value="not_applicable">Not applicable</option>
            </select>
          </label>
          <label>
            Moderation tier requested
            <select value={form.moderationTierRequested} onChange={(e) => updateField("moderationTierRequested", e.target.value)}>
              <option value="community">Community</option>
              <option value="verified">Verified</option>
              <option value="clinician_reviewed">Clinician-reviewed tier</option>
            </select>
          </label>
        </div>

        <div className="grid2 checkboxGrid">
          <label className="checkboxRow">
            <input
              type="checkbox"
              checked={form.healthMdCompatible}
              onChange={(e) => updateField("healthMdCompatible", e.target.checked)}
            />
            <span>Health.md compatible</span>
          </label>
          <label className="checkboxRow">
            <input
              type="checkbox"
              checked={form.createsLinkedFile}
              onChange={(e) => updateField("createsLinkedFile", e.target.checked)}
            />
            <span>Creates linked condition/event file (for example `pregnancy.md`)</span>
          </label>
        </div>

        <div className="grid2">
          <label>
            Linked file names (comma-separated)
            <input
              value={form.linkedFileNames}
              onChange={(e) => updateField("linkedFileNames", e.target.value)}
              placeholder="pregnancy.md"
            />
          </label>
          <label>
            Submitter (optional)
            <input value={form.submitter} onChange={(e) => updateField("submitter", e.target.value)} placeholder="birger" />
          </label>
        </div>

        <label>
          Source URLs (comma-separated)
          <textarea
            rows={3}
            value={form.sourceUrls}
            onChange={(e) => updateField("sourceUrls", e.target.value)}
            placeholder="https://www.cdc.gov/..., https://www.acog.org/..."
          />
        </label>

        <label>
          Notes for moderators (optional)
          <textarea rows={3} value={form.notes} onChange={(e) => updateField("notes", e.target.value)} placeholder="Clinician review in progress, regional focus, etc." />
        </label>

        <div className="submitActions">
          <button className="button solid big" type="submit" disabled={isPending}>
            {isPending ? "Submitting..." : "Submit / Update Skill"}
          </button>
          <p className="finePrint">
            Minimal MVP behavior: submissions are persisted locally in `data/skills.json`. Replace with Cloudflare D1/KV for production hosting.
          </p>
        </div>

        {error ? <div className="alert error">{error}</div> : null}
        {result ? (
          <div className="alert success">
            <strong>{result.type === "update" ? "Update queued" : "New submission queued"}.</strong> {result.skill.title} is now{" "}
            <code>{result.skill.status}</code> with <code>{result.skill.moderationTier}</code> moderation tier.
          </div>
        ) : null}
      </form>
    </div>
  );
}
