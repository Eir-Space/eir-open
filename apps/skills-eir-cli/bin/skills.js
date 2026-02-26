#!/usr/bin/env node

import { spawn } from "node:child_process";

const DEFAULT_API_BASE = process.env.EIR_SKILLS_API || "https://skills.eir.space";

function printHelp() {
  console.log(`skills - CLI for skills.eir.space

Usage:
  skills help
  skills search <query> [--api <url>]
  skills add <owner/repo> [--skill <skill-name>] [--clone] [--dir <path>]
  skills submit --name <skill-name> --repo <github-url> --summary <text> [options]
  skills update --name <skill-name> --repo <github-url> --summary <text> [options]

Common options:
  --api <url>                   API base URL (default: ${DEFAULT_API_BASE})

Submit/Update options:
  --title <text>                Display title
  --path <skill-path>           Skill path in repo (example: pregnancy/)
  --owner <text>                Owner label (example: eir-space)
  --tags <csv>                  Domain tags (example: pregnancy,prenatal-care)
  --populations <csv>           Populations (example: pregnant)
  --regions <csv>               Regions (example: global)
  --review-status <value>       not_medically_reviewed | clinician_reviewed | not_applicable
  --last-reviewed <date>        YYYY-MM-DD
  --source-urls <csv>           Comma-separated source URLs
  --version <semver>            Version string
  --submitter <text>            Submitter name/handle
  --notes <text>                Moderator notes
  --health-md                   Mark health_md_compatible=true
  --creates-linked-file         Mark creates_linked_file=true
  --linked-files <csv>          Linked file names (example: pregnancy.md)

Examples:
  skills search pregnancy
  skills add eir-space/pregnancy --skill pregnancy
  skills submit --name pregnancy --repo https://github.com/Eir-Space/pregnancy --path pregnancy/ --summary "Pregnancy grounding + pregnancy.md" --tags pregnancy,prenatal-care --health-md --creates-linked-file --linked-files pregnancy.md
`);
}

function parseArgs(argv) {
  const positional = [];
  const options = {};

  for (let i = 0; i < argv.length; i += 1) {
    const token = argv[i];
    if (!token.startsWith("--")) {
      positional.push(token);
      continue;
    }
    const key = token.slice(2);
    const next = argv[i + 1];
    if (!next || next.startsWith("--")) {
      options[key] = true;
      continue;
    }
    options[key] = next;
    i += 1;
  }

  return { positional, options };
}

function csv(input) {
  return String(input || "")
    .split(",")
    .map((x) => x.trim())
    .filter(Boolean);
}

function apiBase(options) {
  return String(options.api || DEFAULT_API_BASE).replace(/\/+$/, "");
}

async function fetchJson(url, config = {}) {
  const response = await fetch(url, config);
  const contentType = response.headers.get("content-type") || "";
  const data = contentType.includes("application/json")
    ? await response.json()
    : { error: await response.text() };

  if (!response.ok) {
    throw new Error(data.error || `Request failed (${response.status})`);
  }

  return data;
}

async function runSearch(query, options) {
  if (!query) {
    throw new Error("search requires a query.");
  }
  const base = apiBase(options);
  const url = `${base}/api/skills?q=${encodeURIComponent(query)}`;
  const data = await fetchJson(url);
  const skills = Array.isArray(data.skills) ? data.skills : [];

  if (!skills.length) {
    console.log("No skills found.");
    return;
  }

  for (const skill of skills) {
    console.log(`- ${skill.title} (${skill.name})`);
    console.log(`  owner: @${skill.owner}`);
    console.log(`  repo:  ${skill.repoUrl}`);
    console.log(`  path:  ${skill.skillPath}`);
    console.log(`  tier:  ${skill.moderationTier} | review: ${skill.reviewStatus}`);
    console.log(`  url:   ${base}/skills/${skill.slug}`);
  }
}

function normalizeRepoRef(repoRef) {
  const clean = String(repoRef || "").replace(/^https?:\/\/github\.com\//i, "").replace(/\.git$/, "");
  const parts = clean.split("/");
  if (parts.length !== 2 || !parts[0] || !parts[1]) {
    throw new Error("add requires <owner/repo>.");
  }
  return { owner: parts[0], repo: parts[1], repoUrl: `https://github.com/${parts[0]}/${parts[1]}` };
}

function runClone(repoUrl, targetDir = "") {
  return new Promise((resolve, reject) => {
    const args = ["clone", repoUrl];
    if (targetDir) args.push(targetDir);
    const proc = spawn("git", args, { stdio: "inherit" });
    proc.on("exit", (code) => {
      if (code === 0) resolve();
      else reject(new Error(`git clone failed with exit code ${code}`));
    });
  });
}

async function runAdd(repoRef, options) {
  const { owner, repo, repoUrl } = normalizeRepoRef(repoRef);
  const skillName = String(options.skill || "").trim();

  console.log(`Registry quick-add instructions`);
  console.log(`- repo: ${repoUrl}`);
  if (skillName) console.log(`- skill: ${skillName}`);
  console.log(`- suggested alias: ${owner}/${repo}${skillName ? `#${skillName}` : ""}`);

  if (options.clone) {
    await runClone(repoUrl, String(options.dir || ""));
    console.log("Repository cloned.");
  } else {
    console.log("Use --clone to clone the repository locally.");
  }
}

function toPayload(options) {
  const required = ["name", "repo", "summary"];
  for (const req of required) {
    if (!options[req]) {
      throw new Error(`Missing required option --${req}`);
    }
  }

  return {
    name: options.name,
    title: options.title || "",
    owner: options.owner || "community",
    repoUrl: options.repo,
    skillPath: options.path || "",
    summary: options.summary,
    domainTags: csv(options.tags),
    populations: csv(options.populations),
    regions: csv(options.regions || "global"),
    reviewStatus: options["review-status"] || "not_medically_reviewed",
    lastReviewed: options["last-reviewed"] || "",
    sourceUrls: csv(options["source-urls"]),
    healthMdCompatible: Boolean(options["health-md"]),
    createsLinkedFile: Boolean(options["creates-linked-file"]),
    linkedFileNames: csv(options["linked-files"]),
    version: options.version || "0.1.0",
    submitter: options.submitter || "",
    moderationTierRequested: options.tier || "community",
    notes: options.notes || ""
  };
}

async function runSubmitOrUpdate(kind, options) {
  const base = apiBase(options);
  const payload = toPayload(options);
  const result = await fetchJson(`${base}/api/submit`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(payload)
  });

  console.log(`${kind} completed.`);
  console.log(`- type: ${result.type}`);
  console.log(`- skill: ${result.skill.title} (${result.skill.name})`);
  console.log(`- status: ${result.skill.status}`);
  console.log(`- tier: ${result.skill.moderationTier}`);
  console.log(`- page: ${base}/skills/${result.skill.slug}`);
}

async function main() {
  const { positional, options } = parseArgs(process.argv.slice(2));
  const command = positional[0];

  if (!command || command === "help" || command === "--help") {
    printHelp();
    return;
  }

  if (command === "search") {
    await runSearch(positional.slice(1).join(" "), options);
    return;
  }

  if (command === "add") {
    await runAdd(positional[1], options);
    return;
  }

  if (command === "submit") {
    await runSubmitOrUpdate("submit", options);
    return;
  }

  if (command === "update") {
    await runSubmitOrUpdate("update", options);
    return;
  }

  throw new Error(`Unknown command: ${command}`);
}

main().catch((error) => {
  console.error(`Error: ${error.message}`);
  process.exit(1);
});
