import seedData from "@/data/skills.json";

const d1Config = {
  accountId: process.env.CF_ACCOUNT_ID || "",
  databaseId: process.env.CF_D1_DATABASE_ID || "",
  apiToken: process.env.CF_API_TOKEN || ""
};

function useD1Store() {
  return Boolean(d1Config.accountId && d1Config.databaseId && d1Config.apiToken);
}

function safeArray(value) {
  return Array.isArray(value) ? value : [];
}

function normalizeList(input) {
  if (!input) return [];
  if (Array.isArray(input)) return input.map((x) => String(x).trim()).filter(Boolean);
  return String(input)
    .split(",")
    .map((x) => x.trim())
    .filter(Boolean);
}

export async function readStore() {
  if (useD1Store()) {
    try {
      return await readStoreFromD1();
    } catch (error) {
      console.error("D1 read failed, falling back to seed store:", error?.message || error);
      return readSeedStore();
    }
  }
  return readStoreFromFile();
}

export async function writeStore(data) {
  if (useD1Store()) {
    await writeStoreToD1(data);
    return;
  }
  try {
    const { promises: fs } = await import("node:fs");
    const path = await import("node:path");
    const storePath = path.join(process.cwd(), "data", "skills.json");
    await fs.writeFile(storePath, `${JSON.stringify(data, null, 2)}\n`, "utf8");
  } catch {
    throw new Error(
      "Submission persistence requires Cloudflare D1 in production (set CF_ACCOUNT_ID, CF_D1_DATABASE_ID, CF_API_TOKEN)."
    );
  }
}

async function d1Query(sql, params = []) {
  const response = await fetch(
    `https://api.cloudflare.com/client/v4/accounts/${d1Config.accountId}/d1/database/${d1Config.databaseId}/query`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${d1Config.apiToken}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({ sql, params })
    }
  );

  if (!response.ok) {
    throw new Error(`D1 query failed with status ${response.status}`);
  }

  const payload = await response.json();
  if (!payload.success) {
    const message = payload.errors?.[0]?.message || "D1 query failed";
    throw new Error(message);
  }

  return payload.result?.[0]?.results || [];
}

async function ensureD1Table() {
  await d1Query("CREATE TABLE IF NOT EXISTS skill_store (store_key TEXT PRIMARY KEY, store_value TEXT NOT NULL)");
}

async function readSeedStore() {
  const parsed = seedData;
  return {
    skills: safeArray(parsed.skills),
    submissions: safeArray(parsed.submissions)
  };
}

async function readStoreFromFile() {
  try {
    const { promises: fs } = await import("node:fs");
    const path = await import("node:path");
    const storePath = path.join(process.cwd(), "data", "skills.json");
    const raw = await fs.readFile(storePath, "utf8");
    const parsed = JSON.parse(raw);
    return {
      skills: safeArray(parsed.skills),
      submissions: safeArray(parsed.submissions)
    };
  } catch {
    // Workers runtime has no writable/readable project filesystem.
    return readSeedStore();
  }
}

async function readStoreFromD1() {
  await ensureD1Table();
  const rows = await d1Query("SELECT store_value FROM skill_store WHERE store_key = ?", ["main"]);
  if (!rows.length) {
    const seed = await readSeedStore();
    await writeStoreToD1(seed);
    return seed;
  }

  const parsed = JSON.parse(rows[0].store_value);
  return {
    skills: safeArray(parsed.skills),
    submissions: safeArray(parsed.submissions)
  };
}

async function writeStoreToD1(data) {
  await ensureD1Table();
  await d1Query(
    "INSERT INTO skill_store (store_key, store_value) VALUES (?, ?) ON CONFLICT(store_key) DO UPDATE SET store_value = excluded.store_value",
    ["main", JSON.stringify(data)]
  );
}

export async function listSkills({ q = "", tag = "", reviewStatus = "", moderationTier = "" } = {}) {
  const { skills } = await readStore();
  const query = q.trim().toLowerCase();

  return skills
    .filter((skill) => {
      if (skill.status !== "published") return false;
      if (tag && !safeArray(skill.domainTags).includes(tag)) return false;
      if (reviewStatus && skill.reviewStatus !== reviewStatus) return false;
      if (moderationTier && skill.moderationTier !== moderationTier) return false;
      if (!query) return true;

      const blob = [
        skill.name,
        skill.title,
        skill.summary,
        ...(skill.domainTags || []),
        ...(skill.badges || [])
      ]
        .join(" ")
        .toLowerCase();

      return blob.includes(query);
    })
    .sort((a, b) => {
      const tierOrder = { clinician_reviewed: 3, verified: 2, community: 1 };
      const tierA = tierOrder[a.moderationTier] || 0;
      const tierB = tierOrder[b.moderationTier] || 0;
      if (tierA !== tierB) return tierB - tierA;
      return String(b.updatedAt).localeCompare(String(a.updatedAt));
    });
}

export async function getSkillBySlug(slug) {
  const { skills } = await readStore();
  return skills.find((skill) => skill.slug === slug) || null;
}

function makeSlug(name) {
  return String(name || "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

export async function upsertSubmission(payload) {
  const store = await readStore();
  const now = new Date().toISOString();

  const skillName = String(payload.name || "").trim();
  const slug = makeSlug(skillName);
  if (!skillName || !slug) {
    throw new Error("Skill name is required.");
  }

  const repoUrl = String(payload.repoUrl || "").trim();
  if (!repoUrl.startsWith("https://github.com/")) {
    throw new Error("GitHub repo URL is required.");
  }

  const skillPath = String(payload.skillPath || "").trim() || `${slug}/`;
  const reviewStatus = String(payload.reviewStatus || "not_medically_reviewed");
  const moderationTier = "community";
  const sourceUrls = normalizeList(payload.sourceUrls);
  const domainTags = normalizeList(payload.domainTags);
  const populations = normalizeList(payload.populations);
  const regions = normalizeList(payload.regions);
  const linkedFileNames = normalizeList(payload.linkedFileNames);

  const existing = store.skills.find(
    (skill) => skill.repoUrl === repoUrl && String(skill.skillPath || "") === skillPath
  );

  const record = {
    id: existing?.id || slug,
    slug: existing?.slug || slug,
    name: skillName,
    title: String(payload.title || skillName)
      .trim()
      .replace(/\b\w/g, (m) => m.toUpperCase()),
    owner: String(payload.owner || "community").trim().toLowerCase(),
    repoUrl,
    skillPath,
    domainTags,
    populations,
    regions,
    healthMdCompatible: Boolean(payload.healthMdCompatible),
    createsLinkedFile: Boolean(payload.createsLinkedFile),
    linkedFileNames,
    reviewStatus,
    moderationTier: existing?.moderationTier || moderationTier,
    status: existing ? existing.status : "pending_review",
    badges: [
      payload.healthMdCompatible ? "Health.md Compatible" : null,
      payload.createsLinkedFile && linkedFileNames[0] ? `Creates ${linkedFileNames[0]}` : null,
      reviewStatus === "not_medically_reviewed" ? "Not Medically Reviewed" : null
    ].filter(Boolean),
    summary: String(payload.summary || "").trim(),
    sourceUrls,
    lastReviewed: String(payload.lastReviewed || "").trim() || null,
    version: String(payload.version || "0.1.0").trim(),
    updatedAt: now
  };

  if (existing) {
    Object.assign(existing, record);
  } else {
    store.skills.unshift(record);
  }

  store.submissions.unshift({
    id: `${slug}-${Date.now()}`,
    type: existing ? "update" : "new",
    repoUrl,
    skillPath,
    slug,
    submittedBy: String(payload.submitter || "anonymous").trim() || "anonymous",
    moderationTierRequested: String(payload.moderationTierRequested || "community"),
    notes: String(payload.notes || "").trim(),
    createdAt: now,
    status: "queued"
  });

  await writeStore(store);
  return { skill: record, type: existing ? "update" : "new" };
}

export function getFilterOptions() {
  return {
    reviewStatuses: [
      { value: "", label: "All review states" },
      { value: "not_medically_reviewed", label: "Not medically reviewed" },
      { value: "clinician_reviewed", label: "Clinician reviewed" },
      { value: "not_applicable", label: "Not applicable" }
    ],
    moderationTiers: [
      { value: "", label: "All moderation tiers" },
      { value: "community", label: "Community" },
      { value: "verified", label: "Verified" },
      { value: "clinician_reviewed", label: "Clinician reviewed" }
    ]
  };
}
