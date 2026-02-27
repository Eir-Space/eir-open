import { NextResponse } from "next/server";
import { ingestSkill } from "@/lib/skill-store";
import { buildIngestPayloads, parseRepoRef } from "@/lib/github-ingest";

function isAuthorized(request) {
  const configured = process.env.EIR_INGEST_API_KEY || "";
  if (!configured) return true;
  const header = request.headers.get("x-ingest-key") || "";
  return header && header === configured;
}

export async function POST(request) {
  try {
    if (!isAuthorized(request)) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    const token = process.env.GITHUB_TOKEN || "";
    const defaultRepos = String(process.env.EIR_REGISTRY_REPOS || "")
      .split(",")
      .map((x) => x.trim())
      .filter(Boolean);

    const body = await request.json().catch(() => ({}));
    const repoList = Array.isArray(body.repos) && body.repos.length ? body.repos : defaultRepos;
    const ref = body.ref || "main";

    if (!repoList.length) {
      return NextResponse.json({ error: "No repos provided. Set EIR_REGISTRY_REPOS or pass repos[] in body." }, { status: 400 });
    }

    const summary = [];
    for (const repoInput of repoList) {
      const { owner, repo } = parseRepoRef(repoInput);
      const payloads = await buildIngestPayloads({ owner, repo, ref, token });
      let count = 0;
      for (const payload of payloads) {
        await ingestSkill(payload, {
          submittedBy: "ingestion-bot",
          notes: `Synced from ${owner}/${repo}@${ref}`
        });
        count += 1;
      }
      summary.push({ repo: `${owner}/${repo}`, ingested: count });
    }

    return NextResponse.json({ ref, summary });
  } catch (error) {
    return NextResponse.json({ error: error.message || "Sync failed" }, { status: 400 });
  }
}
