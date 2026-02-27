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

    const body = await request.json();
    const repoInput = body.repo || body.repoUrl;
    const ref = body.ref || "main";
    const token = process.env.GITHUB_TOKEN || "";
    const { owner, repo } = parseRepoRef(repoInput);

    const payloads = await buildIngestPayloads({ owner, repo, ref, token });
    if (!payloads.length) {
      return NextResponse.json({ error: "No SKILL.md files found in repo" }, { status: 404 });
    }

    const results = [];
    for (const payload of payloads) {
      const result = await ingestSkill(payload, {
        submittedBy: "ingestion-bot",
        notes: `Ingested from ${owner}/${repo}@${ref}`
      });
      results.push(result);
    }

    return NextResponse.json({
      repo: `${owner}/${repo}`,
      ref,
      ingested: results.length,
      results
    });
  } catch (error) {
    return NextResponse.json({ error: error.message || "Ingestion failed" }, { status: 400 });
  }
}
