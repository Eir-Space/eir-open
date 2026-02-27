function parseFrontmatter(markdown) {
  const match = String(markdown || "").match(/^---\n([\s\S]*?)\n---\n?/);
  if (!match) return {};
  const lines = match[1].split("\n");
  const out = {};
  for (const line of lines) {
    const idx = line.indexOf(":");
    if (idx < 0) continue;
    const key = line.slice(0, idx).trim();
    const value = line.slice(idx + 1).trim().replace(/^["']|["']$/g, "");
    out[key] = value;
  }
  return out;
}

function inferTags(name, description, path) {
  const blob = `${name} ${description} ${path}`.toLowerCase();
  const tags = new Set();
  if (blob.includes("pregnancy")) tags.add("pregnancy");
  if (blob.includes("diabetes")) tags.add("diabetes");
  if (blob.includes("triage")) tags.add("triage");
  if (blob.includes("health.md")) tags.add("health-md");
  if (blob.includes("search") || blob.includes("find")) tags.add("discovery");
  if (!tags.size) tags.add("health");
  return [...tags];
}

function inferLinkedFiles(name, description) {
  const blob = `${name} ${description}`.toLowerCase();
  if (blob.includes("pregnancy")) return ["pregnancy.md"];
  if (blob.includes("diabetes")) return ["diabetes.md"];
  return [];
}

async function githubRequest(url, token) {
  const response = await fetch(url, {
    headers: {
      Accept: "application/vnd.github+json",
      ...(token ? { Authorization: `Bearer ${token}` } : {})
    }
  });
  if (!response.ok) {
    throw new Error(`GitHub request failed (${response.status}) for ${url}`);
  }
  return response.json();
}

async function fetchText(url, token) {
  const response = await fetch(url, {
    headers: {
      ...(token ? { Authorization: `Bearer ${token}` } : {})
    }
  });
  if (!response.ok) {
    throw new Error(`Failed to fetch file (${response.status})`);
  }
  return response.text();
}

export async function discoverSkillFiles({ owner, repo, ref = "main", token = "" }) {
  const tree = await githubRequest(
    `https://api.github.com/repos/${owner}/${repo}/git/trees/${encodeURIComponent(ref)}?recursive=1`,
    token
  );

  const items = Array.isArray(tree.tree) ? tree.tree : [];
  return items
    .filter((item) => item.type === "blob" && /(^|\/)SKILL\.md$/i.test(item.path))
    .map((item) => item.path);
}

export async function buildIngestPayloads({ owner, repo, ref = "main", token = "" }) {
  const skillFiles = await discoverSkillFiles({ owner, repo, ref, token });
  const payloads = [];

  for (const skillFile of skillFiles) {
    const rawUrl = `https://raw.githubusercontent.com/${owner}/${repo}/${ref}/${skillFile}`;
    const markdown = await fetchText(rawUrl, token);
    const fm = parseFrontmatter(markdown);
    const name = fm.name || skillFile.split("/").slice(-2, -1)[0] || repo;
    const description = fm.description || "";
    const tags = inferTags(name, description, skillFile);
    const linkedFileNames = inferLinkedFiles(name, description);

    payloads.push({
      name,
      title: name.replace(/(^|-)([a-z])/g, (_, a, b) => `${a}${b.toUpperCase()}`),
      owner,
      repoUrl: `https://github.com/${owner}/${repo}`,
      skillPath: skillFile.replace(/SKILL\.md$/i, ""),
      summary: description || `${name} skill from ${owner}/${repo}`,
      domainTags: tags,
      populations: ["general"],
      regions: ["global"],
      reviewStatus: "not_medically_reviewed",
      lastReviewed: null,
      sourceUrls: [],
      healthMdCompatible: /health|pregnancy|diabetes|triage/i.test(name + description),
      createsLinkedFile: linkedFileNames.length > 0,
      linkedFileNames,
      version: "0.1.0",
      moderationTierRequested: "community"
    });
  }

  return payloads;
}

export function parseRepoRef(repo) {
  const clean = String(repo || "")
    .trim()
    .replace(/^https?:\/\/github\.com\//i, "")
    .replace(/\.git$/i, "");
  const [owner, name] = clean.split("/");
  if (!owner || !name) {
    throw new Error("repo must be in format owner/repo or full GitHub URL");
  }
  return { owner, repo: name };
}
