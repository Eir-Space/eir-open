import { Fragment, useMemo, useState, type Dispatch, type SetStateAction } from 'react';
import {
  top100DiseaseRankings,
  scoreDisease,
  type DiseaseWorkflowKit,
} from '@/data/aiDiseaseRankings';

type RankedDisease = DiseaseWorkflowKit & {
  rank: number;
  total: number;
};

const weightLabels = [
  ['Search space', '4x'],
  ['Data burden', '4x'],
  ['Personalization', '5x'],
  ['Actionability', '4x'],
  ['Compute elasticity', '3x'],
] as const;

function rankDiseases(rankings: DiseaseWorkflowKit[]): RankedDisease[] {
  return rankings
    .map((ranking, index) => ({
      ...ranking,
      index,
      total: scoreDisease(ranking),
    }))
    .sort((left, right) => right.total - left.total || left.index - right.index)
    .map(({ index: _index, ...ranking }, index) => ({
      ...ranking,
      rank: index + 1,
    }));
}

export default function DiseaseRankingTable() {
  const rankings = top100DiseaseRankings;
  const [query, setQuery] = useState('');
  const [category, setCategory] = useState('All');
  const [expandedDisease, setExpandedDisease] = useState<string | null>(rankings[0]?.disease ?? null);
  const [copiedKey, setCopiedKey] = useState<string | null>(null);

  const ranked = useMemo(() => rankDiseases(rankings), [rankings]);
  const categories = useMemo(
    () => ['All', ...new Set(ranked.map((ranking) => ranking.category))],
    [ranked]
  );

  const filtered = useMemo(() => {
    const normalizedQuery = query.trim().toLowerCase();

    return ranked.filter((ranking) => {
      const matchesCategory = category === 'All' || ranking.category === category;
      const haystack =
        `${ranking.disease} ${ranking.category} ${ranking.why} ${ranking.prompt} ${ranking.requiredInformation.join(' ')}`.toLowerCase();
      const matchesQuery = !normalizedQuery || haystack.includes(normalizedQuery);

      return matchesCategory && matchesQuery;
    });
  }, [category, query, ranked]);

  const topTen = ranked.slice(0, 10);

  async function copyText(key: string, text: string) {
    await navigator.clipboard.writeText(text);
    setCopiedKey(key);
    window.setTimeout(() => setCopiedKey((current) => (current === key ? null : current)), 1500);
  }

  return (
    <section className="not-content space-y-6">
      <style>{`
        @keyframes kitReveal {
          0% {
            opacity: 0;
            transform: translateY(12px) scale(0.985);
          }
          100% {
            opacity: 1;
            transform: translateY(0) scale(1);
          }
        }
      `}</style>
      <div className="grid gap-4 xl:grid-cols-[1.15fr_0.85fr]">
        <div className="rounded-[1.75rem] border border-[var(--border-subtle)] bg-[linear-gradient(135deg,rgba(30,95,109,0.14),rgba(232,168,48,0.14))] p-6 shadow-[var(--card-shadow)]">
          <div className="flex flex-wrap items-center gap-3 text-xs font-semibold uppercase tracking-[0.18em] text-[var(--muted-foreground)]">
            <span>Top 100 ranking</span>
            <span className="rounded-full border border-[var(--border-subtle)] bg-[var(--card)] px-3 py-1 text-[10px] text-[var(--foreground)]">
              5-factor score
            </span>
          </div>
          <h2 className="mt-3 text-3xl font-semibold tracking-tight text-[var(--foreground)]">
            Where more AI tokens are most likely to change clinical decisions
          </h2>
          <p className="mt-3 max-w-3xl text-sm leading-7 text-[var(--muted-foreground)]">
            The ranking is sorted by a weighted score from 0 to 100. It rewards diseases
            with large decision spaces, heavy multimodal data, strong need for patient-level
            personalization, actionable downstream choices, and clear benefit from extra
            inference budget.
          </p>
          <p className="mt-3 max-w-3xl text-sm leading-7 text-[var(--muted-foreground)]">
            Each disease now includes a copyable prompt and a detailed checklist of information
            you should gather before asking an AI system to reason about that case.
          </p>
          <div className="mt-6 flex flex-wrap gap-3">
            {weightLabels.map(([label, weight]) => (
              <div
                key={label}
                className="rounded-2xl border border-[var(--border-subtle)] bg-[var(--card)] px-4 py-3 shadow-[var(--card-shadow)]"
              >
                <div className="text-xs uppercase tracking-[0.16em] text-[var(--muted-foreground)]">
                  {label}
                </div>
                <div className="mt-1 text-lg font-semibold text-[var(--foreground)]">{weight}</div>
              </div>
            ))}
          </div>
        </div>

        <div className="rounded-[1.75rem] border border-[var(--border-subtle)] bg-[var(--card)] p-6 shadow-[var(--card-shadow)]">
          <div className="text-xs font-semibold uppercase tracking-[0.18em] text-[var(--muted-foreground)]">
            Why the top stays the top
          </div>
          <div className="mt-4 space-y-3">
            {topTen.map((ranking) => (
              <div
                key={ranking.disease}
                className="rounded-2xl border border-[var(--border-subtle)] bg-[var(--background-soft)] px-4 py-3"
              >
                <div className="flex items-center justify-between gap-4">
                  <div className="min-w-0">
                    <div className="text-sm font-semibold text-[var(--foreground)]">
                      #{ranking.rank} {ranking.disease}
                    </div>
                    <div className="mt-1 text-xs uppercase tracking-[0.16em] text-[var(--muted-foreground)]">
                      {ranking.category}
                    </div>
                  </div>
                  <div className="rounded-full bg-[var(--primary)] px-3 py-1 text-sm font-semibold text-[var(--primary-foreground)]">
                    {ranking.total}
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>

      <div className="grid gap-3 rounded-[1.5rem] border border-[var(--border-subtle)] bg-[var(--card)] p-4 shadow-[var(--card-shadow)] md:grid-cols-[1fr_auto]">
        <label className="flex flex-col gap-2 text-sm font-medium text-[var(--foreground)]">
          Search diseases, categories, or rationale
          <input
            className="h-11 rounded-xl border border-[var(--border-subtle)] bg-[var(--background)] px-4 text-sm text-[var(--foreground)] outline-none transition focus:border-[var(--primary)] focus:ring-4 focus:ring-[var(--focus-ring)]"
            type="search"
            value={query}
            placeholder="Try 'oncology', 'sepsis', or 'polypharmacy'"
            onChange={(event) => setQuery(event.target.value)}
          />
        </label>

        <label className="flex flex-col gap-2 text-sm font-medium text-[var(--foreground)]">
          Category
          <select
            className="h-11 min-w-[16rem] rounded-xl border border-[var(--border-subtle)] bg-[var(--background)] px-4 text-sm text-[var(--foreground)] outline-none transition focus:border-[var(--primary)] focus:ring-4 focus:ring-[var(--focus-ring)]"
            value={category}
            onChange={(event) => setCategory(event.target.value)}
          >
            {categories.map((option) => (
              <option key={option} value={option}>
                {option}
              </option>
            ))}
          </select>
        </label>
      </div>

      <div className="space-y-4 md:hidden">
        {filtered.map((ranking) => (
          <MobileDiseaseCard
            key={ranking.disease}
            ranking={ranking}
            expandedDisease={expandedDisease}
            copiedKey={copiedKey}
            onCopy={copyText}
            onToggle={setExpandedDisease}
          />
        ))}
      </div>

      <div className="hidden overflow-hidden rounded-[1.5rem] border border-[var(--border-subtle)] bg-[var(--card)] shadow-[var(--card-shadow)] md:block">
        <div className="overflow-x-auto">
          <table className="min-w-full w-full table-fixed border-collapse">
            <colgroup>
              <col style={{ width: '6%' }} />
              <col style={{ width: '20%' }} />
              <col style={{ width: '14%' }} />
              <col style={{ width: '8%' }} />
              <col style={{ width: '18%' }} />
              <col style={{ width: '25%' }} />
              <col style={{ width: '9%' }} />
            </colgroup>
            <thead>
              <tr className="bg-[var(--background-soft)] text-left text-xs uppercase tracking-[0.16em] text-[var(--muted-foreground)]">
                <th className="px-3 py-4 font-semibold">Rank</th>
                <th className="px-3 py-4 font-semibold">Disease</th>
                <th className="px-3 py-4 font-semibold">Category</th>
                <th className="px-3 py-4 font-semibold">Score</th>
                <th className="px-3 py-4 font-semibold">Dimensions</th>
                <th className="px-3 py-4 font-semibold">Why AI compute helps</th>
                <th className="px-3 py-4 font-semibold">Prompt kit</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((ranking) => (
                <Fragment key={ranking.disease}>
                  <tr
                    className="border-t border-[var(--border-subtle)] align-top text-sm text-[var(--foreground)]"
                  >
                    <td className="px-3 py-4 font-semibold">{ranking.rank}</td>
                    <td className="px-3 py-4">
                      <div className="text-[0.97rem] font-semibold leading-8">{ranking.disease}</div>
                    </td>
                    <td className="px-3 py-4">
                      <span className="inline-flex rounded-full bg-[var(--background-soft)] px-2.5 py-1 text-[11px] font-medium leading-5 text-[var(--foreground)]">
                        {ranking.category}
                      </span>
                    </td>
                    <td className="px-3 py-4">
                      <div className="inline-flex rounded-full bg-[var(--primary)] px-3 py-1 text-sm font-semibold text-[var(--primary-foreground)]">
                        {ranking.total}
                      </div>
                    </td>
                    <td className="px-3 py-4">
                      <div className="grid gap-2">
                        <Metric label="Search" value={ranking.searchSpace} />
                        <Metric label="Data" value={ranking.dataBurden} />
                        <Metric label="Personal." value={ranking.personalization} />
                        <Metric label="Action." value={ranking.actionability} />
                        <Metric label="Compute" value={ranking.computeElasticity} />
                      </div>
                    </td>
                    <td className="px-3 py-4 text-[15px] leading-7 text-[var(--muted-foreground)]">
                      {ranking.why}
                    </td>
                    <td className="px-3 py-4">
                      <button
                        className="inline-flex rounded-full border border-[var(--border-subtle)] bg-[var(--card)] px-3 py-2 text-[11px] font-semibold uppercase tracking-[0.14em] text-[var(--foreground)] transition hover:border-[var(--primary)] hover:text-[var(--primary)]"
                        onClick={() =>
                          setExpandedDisease((current) =>
                            current === ranking.disease ? null : ranking.disease
                          )
                        }
                        type="button"
                      >
                        {expandedDisease === ranking.disease ? 'Hide kit' : 'Show kit'}
                      </button>
                    </td>
                  </tr>
                  {expandedDisease === ranking.disease && (
                    <tr className="border-t border-[var(--border-subtle)] bg-[var(--background-soft)]">
                      <td className="px-4 py-5" colSpan={7}>
                        <div
                          className="grid gap-4 xl:grid-cols-[1.1fr_0.9fr]"
                          style={{
                            animation: 'kitReveal 240ms cubic-bezier(0.22, 1, 0.36, 1)',
                            transformOrigin: 'top center',
                          }}
                        >
                          <div className="rounded-[1.25rem] border border-[var(--border-subtle)] bg-[var(--card)] p-4 shadow-[var(--card-shadow)]">
                            <div className="flex flex-wrap items-center justify-between gap-3">
                              <div>
                                <div className="text-xs font-semibold uppercase tracking-[0.16em] text-[var(--muted-foreground)]">
                                  Copyable prompt
                                </div>
                                <div className="mt-1 text-sm font-semibold text-[var(--foreground)]">
                                  Paste this into an AI system for {ranking.disease}
                                </div>
                              </div>
                              <button
                                className="inline-flex rounded-full bg-[var(--primary)] px-3 py-2 text-xs font-semibold uppercase tracking-[0.14em] text-[var(--primary-foreground)]"
                                onClick={() => copyText(`prompt-${ranking.disease}`, ranking.prompt)}
                                type="button"
                              >
                                {copiedKey === `prompt-${ranking.disease}` ? 'Copied' : 'Copy prompt'}
                              </button>
                            </div>
                            <pre className="mt-4 overflow-x-auto rounded-2xl border border-[var(--border-subtle)] bg-[var(--background)] p-4 text-xs leading-6 whitespace-pre-wrap text-[var(--foreground)]">
                              {ranking.prompt}
                            </pre>
                          </div>

                          <div className="space-y-4">
                            <div className="rounded-[1.25rem] border border-[var(--border-subtle)] bg-[var(--card)] p-4 shadow-[var(--card-shadow)]">
                              <div className="flex flex-wrap items-center justify-between gap-3">
                                <div className="text-xs font-semibold uppercase tracking-[0.16em] text-[var(--muted-foreground)]">
                                  Information needed
                                </div>
                                <button
                                  className="inline-flex rounded-full border border-[var(--border-subtle)] px-3 py-2 text-xs font-semibold uppercase tracking-[0.14em] text-[var(--foreground)]"
                                  onClick={() =>
                                    copyText(
                                      `info-${ranking.disease}`,
                                      ranking.requiredInformation.map((item, index) => `${index + 1}. ${item}`).join('\n')
                                    )
                                  }
                                  type="button"
                                >
                                  {copiedKey === `info-${ranking.disease}` ? 'Copied' : 'Copy checklist'}
                                </button>
                              </div>
                              <ol className="mt-3 space-y-2 pl-5 text-sm leading-6 text-[var(--muted-foreground)]">
                                {ranking.requiredInformation.map((item) => (
                                  <li key={item}>{item}</li>
                                ))}
                              </ol>
                            </div>

                            <div className="rounded-[1.25rem] border border-[var(--border-subtle)] bg-[var(--card)] p-4 shadow-[var(--card-shadow)]">
                              <div className="text-xs font-semibold uppercase tracking-[0.16em] text-[var(--muted-foreground)]">
                                Expected output from the AI
                              </div>
                              <ol className="mt-3 space-y-2 pl-5 text-sm leading-6 text-[var(--muted-foreground)]">
                                {ranking.expectedOutput.map((item) => (
                                  <li key={item}>{item}</li>
                                ))}
                              </ol>
                            </div>
                          </div>
                        </div>
                      </td>
                    </tr>
                  )}
                </Fragment>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </section>
  );
}

function MobileDiseaseCard({
  ranking,
  expandedDisease,
  copiedKey,
  onCopy,
  onToggle,
}: {
  ranking: RankedDisease;
  expandedDisease: string | null;
  copiedKey: string | null;
  onCopy: (key: string, text: string) => Promise<void>;
  onToggle: Dispatch<SetStateAction<string | null>>;
}) {
  const isExpanded = expandedDisease === ranking.disease;

  return (
    <article className="overflow-hidden rounded-[1.35rem] border border-[var(--border-subtle)] bg-[var(--card)] shadow-[var(--card-shadow)]">
      <div className="space-y-4 p-4">
        <div className="flex items-start justify-between gap-3">
          <div className="min-w-0">
            <div className="text-[11px] font-semibold uppercase tracking-[0.16em] text-[var(--muted-foreground)]">
              Rank #{ranking.rank}
            </div>
            <h3 className="mt-2 text-lg font-semibold leading-7 text-[var(--foreground)]">
              {ranking.disease}
            </h3>
          </div>
          <div className="shrink-0 rounded-full bg-[var(--primary)] px-3 py-1 text-sm font-semibold text-[var(--primary-foreground)]">
            {ranking.total}
          </div>
        </div>

        <div className="flex flex-wrap gap-2">
          <span className="inline-flex rounded-full bg-[var(--background-soft)] px-2.5 py-1 text-[11px] font-medium leading-5 text-[var(--foreground)]">
            {ranking.category}
          </span>
        </div>

        <div className="rounded-[1rem] border border-[var(--border-subtle)] bg-[var(--background-soft)] p-3">
          <div className="text-[11px] font-semibold uppercase tracking-[0.16em] text-[var(--muted-foreground)]">
            Dimensions
          </div>
          <div className="mt-3 grid gap-2">
            <Metric label="Search" value={ranking.searchSpace} />
            <Metric label="Data" value={ranking.dataBurden} />
            <Metric label="Personal." value={ranking.personalization} />
            <Metric label="Action." value={ranking.actionability} />
            <Metric label="Compute" value={ranking.computeElasticity} />
          </div>
        </div>

        <div>
          <div className="text-[11px] font-semibold uppercase tracking-[0.16em] text-[var(--muted-foreground)]">
            Why AI compute helps
          </div>
          <p className="mt-2 text-sm leading-7 text-[var(--muted-foreground)]">{ranking.why}</p>
        </div>

        <button
          className="inline-flex w-full items-center justify-center rounded-full border border-[var(--border-subtle)] bg-[var(--card)] px-4 py-3 text-[11px] font-semibold uppercase tracking-[0.14em] text-[var(--foreground)] transition hover:border-[var(--primary)] hover:text-[var(--primary)]"
          onClick={() => onToggle((current) => (current === ranking.disease ? null : ranking.disease))}
          type="button"
        >
          {isExpanded ? 'Hide kit' : 'Show kit'}
        </button>
      </div>

      {isExpanded && (
        <div
          className="grid gap-4 border-t border-[var(--border-subtle)] bg-[var(--background-soft)] p-4"
          style={{
            animation: 'kitReveal 240ms cubic-bezier(0.22, 1, 0.36, 1)',
            transformOrigin: 'top center',
          }}
        >
          <div className="rounded-[1.15rem] border border-[var(--border-subtle)] bg-[var(--card)] p-4 shadow-[var(--card-shadow)]">
            <div className="flex flex-wrap items-center justify-between gap-3">
              <div>
                <div className="text-xs font-semibold uppercase tracking-[0.16em] text-[var(--muted-foreground)]">
                  Copyable prompt
                </div>
                <div className="mt-1 text-sm font-semibold text-[var(--foreground)]">
                  Paste this into an AI system for {ranking.disease}
                </div>
              </div>
              <button
                className="inline-flex rounded-full bg-[var(--primary)] px-3 py-2 text-xs font-semibold uppercase tracking-[0.14em] text-[var(--primary-foreground)]"
                onClick={() => onCopy(`prompt-${ranking.disease}`, ranking.prompt)}
                type="button"
              >
                {copiedKey === `prompt-${ranking.disease}` ? 'Copied' : 'Copy prompt'}
              </button>
            </div>
            <pre className="mt-4 overflow-x-auto rounded-2xl border border-[var(--border-subtle)] bg-[var(--background)] p-4 text-xs leading-6 whitespace-pre-wrap text-[var(--foreground)]">
              {ranking.prompt}
            </pre>
          </div>

          <div className="space-y-4">
            <div className="rounded-[1.15rem] border border-[var(--border-subtle)] bg-[var(--card)] p-4 shadow-[var(--card-shadow)]">
              <div className="flex flex-wrap items-center justify-between gap-3">
                <div className="text-xs font-semibold uppercase tracking-[0.16em] text-[var(--muted-foreground)]">
                  Information needed
                </div>
                <button
                  className="inline-flex rounded-full border border-[var(--border-subtle)] px-3 py-2 text-xs font-semibold uppercase tracking-[0.14em] text-[var(--foreground)]"
                  onClick={() =>
                    onCopy(
                      `info-${ranking.disease}`,
                      ranking.requiredInformation.map((item, index) => `${index + 1}. ${item}`).join('\n')
                    )
                  }
                  type="button"
                >
                  {copiedKey === `info-${ranking.disease}` ? 'Copied' : 'Copy checklist'}
                </button>
              </div>
              <ol className="mt-3 space-y-2 pl-5 text-sm leading-6 text-[var(--muted-foreground)]">
                {ranking.requiredInformation.map((item) => (
                  <li key={item}>{item}</li>
                ))}
              </ol>
            </div>

            <div className="rounded-[1.15rem] border border-[var(--border-subtle)] bg-[var(--card)] p-4 shadow-[var(--card-shadow)]">
              <div className="text-xs font-semibold uppercase tracking-[0.16em] text-[var(--muted-foreground)]">
                Expected output from the AI
              </div>
              <ol className="mt-3 space-y-2 pl-5 text-sm leading-6 text-[var(--muted-foreground)]">
                {ranking.expectedOutput.map((item) => (
                  <li key={item}>{item}</li>
                ))}
              </ol>
            </div>
          </div>
        </div>
      )}
    </article>
  );
}

function Metric({ label, value }: { label: string; value: number }) {
  return (
    <div className="grid grid-cols-[4.5rem_auto] items-center gap-2 sm:grid-cols-[5rem_auto]">
      <span className="min-w-0 text-[10px] uppercase tracking-[0.12em] text-[var(--muted-foreground)]">
        {label}
      </span>
      <div className="flex shrink-0 items-center gap-1">
        {Array.from({ length: 5 }, (_, index) => (
          <span
            key={`${label}-${index + 1}`}
            className={`h-1.9 w-1.9 rounded-full border ${
              index < value
                ? 'border-[color-mix(in_srgb,var(--primary)_18%,transparent)] bg-[color-mix(in_srgb,var(--primary)_68%,white_32%)] shadow-[0_0_0_1px_color-mix(in_srgb,var(--primary)_6%,transparent)]'
                : 'border-[var(--border-subtle)] bg-[var(--background-soft)]'
            }`}
            style={{ width: '0.5rem', height: '0.5rem' }}
          />
        ))}
      </div>
    </div>
  );
}
