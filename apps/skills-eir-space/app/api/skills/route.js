import { NextResponse } from "next/server";
import { getFilterOptions, listSkills, readStore } from "@/lib/skill-store";

export async function GET(request) {
  try {
    const { searchParams } = new URL(request.url);
    const q = searchParams.get("q") || "";
    const tag = searchParams.get("tag") || "";
    const reviewStatus = searchParams.get("review") || "";
    const moderationTier = searchParams.get("tier") || "";

    const [skills, store] = await Promise.all([
      listSkills({ q, tag, reviewStatus, moderationTier }),
      readStore()
    ]);

    return NextResponse.json({
      skills,
      filters: getFilterOptions(),
      tags: [...new Set(store.skills.flatMap((s) => s.domainTags || []))].sort()
    });
  } catch (error) {
    return NextResponse.json({ error: error.message || "Failed to list skills" }, { status: 500 });
  }
}
