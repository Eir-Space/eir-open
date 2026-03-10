'use client';

import { useState, useTransition } from 'react';

const initialState = {
  name: '',
  title: '',
  owner: 'eir-space',
  repoUrl: '',
  skillPath: '',
  summary: '',
  domainTags: '',
  populations: '',
  regions: 'global',
  reviewStatus: 'not_medically_reviewed',
  lastReviewed: '',
  sourceUrls: '',
  healthMdCompatible: true,
  createsLinkedFile: false,
  linkedFileNames: '',
  version: '0.1.0',
  submitter: '',
  moderationTierRequested: 'community',
  notes: '',
};

function splitCsv(input) {
  return String(input || '')
    .split(',')
    .map((value) => value.trim())
    .filter(Boolean);
}

function slugify(input) {
  return String(input || '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

export function SubmitForm() {
  const [form, setForm] = useState(initialState);
  const [result, setResult] = useState(null);
  const [error, setError] = useState('');
  const [isPending, startTransition] = useTransition();

  function updateField(key, value) {
    setForm((prev) => ({ ...prev, [key]: value }));
  }

  async function submitForm() {
    try {
      const response = await fetch('/api/submit', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(form),
      });

      const data = await response.json();
      if (!response.ok) {
        throw new Error(data?.error || 'Submission failed');
      }

      setResult(data);
      setForm((prev) => ({
        ...initialState,
        owner: prev.owner || 'eir-space',
        reviewStatus: prev.reviewStatus,
        moderationTierRequested: prev.moderationTierRequested,
      }));
    } catch (err) {
      setError(err.message || 'Submission failed');
    }
  }

  async function handleSubmit(event) {
    event.preventDefault();
    setError('');
    setResult(null);

    startTransition(() => {
      void submitForm();
    });
  }

  const slug = slugify(form.name);
  const tagPreview = splitCsv(form.domainTags);
  const linkedFiles = splitCsv(form.linkedFileNames);
  const sourceUrls = splitCsv(form.sourceUrls);
  const previewTitle = form.title.trim() || form.name.trim() || 'Untitled healthcare skill';
  const previewPath = form.skillPath.trim() || `skills/${slug || 'condition-skill'}/`;

  return (
    <div className="submissionStudio">
      <form className="submitForm" onSubmit={handleSubmit}>
        <div className="formSection">
          <div className="sectionTitle">
            <h2>Skill identity</h2>
            <p>Name the skill the way it should appear in the registry.</p>
          </div>
          <div className="grid2">
            <label>
              Skill name
              <input
                value={form.name}
                onChange={(event) => updateField('name', event.target.value)}
                placeholder="medication-reconciliation"
                required
              />
            </label>
            <label>
              Display title
              <input
                value={form.title}
                onChange={(event) => updateField('title', event.target.value)}
                placeholder="Medication Reconciliation"
              />
            </label>
          </div>

          <div className="grid2">
            <label>
              Owner
              <input
                value={form.owner}
                onChange={(event) => updateField('owner', event.target.value)}
                placeholder="eir-space"
              />
            </label>
            <label>
              Version
              <input
                value={form.version}
                onChange={(event) => updateField('version', event.target.value)}
                placeholder="0.1.0"
              />
            </label>
          </div>
        </div>

        <div className="formSection">
          <div className="sectionTitle">
            <h2>Repo source</h2>
            <p>Give the registry a GitHub URL and the folder that contains the skill.</p>
          </div>
          <label>
            GitHub repo URL
            <input
              value={form.repoUrl}
              onChange={(event) => updateField('repoUrl', event.target.value)}
              placeholder="https://github.com/Eir-Space/medication-reconciliation"
              required
            />
          </label>

          <div className="grid2">
            <label>
              Skill path
              <input
                value={form.skillPath}
                onChange={(event) => updateField('skillPath', event.target.value)}
                placeholder="skills/medication-reconciliation/"
              />
            </label>
            <label>
              Last reviewed (optional)
              <input
                value={form.lastReviewed}
                onChange={(event) => updateField('lastReviewed', event.target.value)}
                placeholder="2026-03-09"
              />
            </label>
          </div>
        </div>

        <div className="formSection">
          <div className="sectionTitle">
            <h2>Catalog metadata</h2>
            <p>Explain what the skill does and where it fits.</p>
          </div>
          <label>
            Summary
            <textarea
              rows={4}
              value={form.summary}
              onChange={(event) => updateField('summary', event.target.value)}
              placeholder="Reconciles home, inpatient, and discharge medication lists; flags duplicates, missing indications, route or dose mismatches, and allergy or interaction risks for clinician review."
              required
            />
          </label>

          <div className="grid3">
            <label>
              Domain tags
              <input
                value={form.domainTags}
                onChange={(event) => updateField('domainTags', event.target.value)}
                placeholder="medications, reconciliation, inpatient-safety"
              />
            </label>
            <label>
              Populations
              <input
                value={form.populations}
                onChange={(event) => updateField('populations', event.target.value)}
                placeholder="adults, polypharmacy"
              />
            </label>
            <label>
              Regions
              <input
                value={form.regions}
                onChange={(event) => updateField('regions', event.target.value)}
                placeholder="global"
              />
            </label>
          </div>
        </div>

        <div className="formSection">
          <div className="sectionTitle">
            <h2>Trust signals</h2>
            <p>These flags shape badges and moderation display in the catalog.</p>
          </div>
          <div className="grid2">
            <label>
              Review status
              <select
                value={form.reviewStatus}
                onChange={(event) => updateField('reviewStatus', event.target.value)}
              >
                <option value="not_medically_reviewed">Not medically reviewed</option>
                <option value="clinician_reviewed">Clinician reviewed</option>
                <option value="not_applicable">Not applicable</option>
              </select>
            </label>
            <label>
              Moderation tier requested
              <select
                value={form.moderationTierRequested}
                onChange={(event) => updateField('moderationTierRequested', event.target.value)}
              >
                <option value="community">Community</option>
                <option value="verified">Verified</option>
                <option value="clinician_reviewed">Clinician-reviewed tier</option>
              </select>
            </label>
          </div>

          <div className="checkboxGrid">
            <label className="checkboxRow">
              <input
                type="checkbox"
                checked={form.healthMdCompatible}
                onChange={(event) => updateField('healthMdCompatible', event.target.checked)}
              />
              <span>Health.md compatible</span>
            </label>
            <label className="checkboxRow">
              <input
                type="checkbox"
                checked={form.createsLinkedFile}
                onChange={(event) => updateField('createsLinkedFile', event.target.checked)}
              />
              <span>Creates linked condition or event file</span>
            </label>
          </div>

          <div className="grid2">
            <label>
              Linked file names
              <input
                value={form.linkedFileNames}
                onChange={(event) => updateField('linkedFileNames', event.target.value)}
                placeholder="medications.md"
              />
            </label>
            <label>
              Submitter
              <input
                value={form.submitter}
                onChange={(event) => updateField('submitter', event.target.value)}
                placeholder="birger"
              />
            </label>
          </div>

          <label>
            Source URLs
            <textarea
              rows={3}
              value={form.sourceUrls}
              onChange={(event) => updateField('sourceUrls', event.target.value)}
              placeholder="https://www.who.int/teams/integrated-health-services/patient-safety/medication-safety, https://www.ahrq.gov/patient-safety/settings/hospital/match/index.html"
            />
          </label>
        </div>

        <label>
          Notes for moderators (optional)
          <textarea
            rows={3}
            value={form.notes}
            onChange={(event) => updateField('notes', event.target.value)}
            placeholder="Hospital admissions workflow first; needs pharmacist and internal medicine review before verified tier."
          />
        </label>

        <div className="submitActions">
          <button className="button solid" type="submit" disabled={isPending}>
            {isPending ? 'Submitting…' : 'Submit skill'}
          </button>
          <p className="finePrint">
            Public submissions are accepted into the queue immediately. Moderation tier and review
            badges may change after review.
          </p>
          {error ? <div className="alert error">{error}</div> : null}
          {result ? (
            <div className="alert success">
              Submitted {result.skill?.title} as a {result.type}. Status: {result.skill?.status}.{' '}
              <a href={`/skills/${result.skill?.slug}`}>Open detail page</a>.
            </div>
          ) : null}
        </div>
      </form>

      <aside className="previewPanel">
        <p className="eyebrow accent">Live preview</p>
        <div className="previewCard">
          <div className="previewHeader">
            <div>
              <p className="eyebrow">@{form.owner || 'eir-space'}</p>
              <h3>{previewTitle}</h3>
              <p className="skillSlug">
                {slug || 'skill-name'} <span aria-hidden="true">·</span> {previewPath}
              </p>
            </div>
            <span className={`pill tier ${form.moderationTierRequested}`}>
              {form.moderationTierRequested}
            </span>
          </div>
          <p className="summary">
            {form.summary || 'Your summary will appear here as soon as you describe the skill.'}
          </p>
          <div className="pillRow">
            {tagPreview.length ? (
              tagPreview.map((tag) => (
                <span key={tag} className="pill soft">
                  {tag}
                </span>
              ))
            ) : (
              <span className="pill soft">No tags yet</span>
            )}
          </div>
          <div className="metaRow compact">
            <span>{form.healthMdCompatible ? 'Health.md ready' : 'General skill'}</span>
            <span>
              {form.createsLinkedFile && linkedFiles.length
                ? `Creates ${linkedFiles.join(', ')}`
                : 'No linked file'}
            </span>
            <span>{sourceUrls.length} source link(s)</span>
          </div>
        </div>

        <div className="previewNote">
          <h3>Submission rules</h3>
          <ul className="checklist">
            <li>Repo URL must point to GitHub.</li>
            <li>Skill path should resolve to the folder containing <code>SKILL.md</code>.</li>
            <li>Use clear tags so search and featured tracks work well.</li>
          </ul>
        </div>
      </aside>
    </div>
  );
}
