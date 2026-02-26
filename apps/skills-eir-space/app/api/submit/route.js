import { NextResponse } from "next/server";
import { upsertSubmission } from "@/lib/skill-store";

export async function POST(request) {
  try {
    const payload = await request.json();
    const result = await upsertSubmission(payload);
    return NextResponse.json(result);
  } catch (error) {
    return NextResponse.json({ error: error.message || "Submission failed" }, { status: 400 });
  }
}
