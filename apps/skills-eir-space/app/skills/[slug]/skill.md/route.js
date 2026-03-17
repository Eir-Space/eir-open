import { getLocalSkillDocument, getSkillBySlug } from '@/lib/skill-store';

export async function GET(_request, { params }) {
  const resolvedParams = await Promise.resolve(params || {});
  const skill = await getSkillBySlug(resolvedParams.slug);

  if (!skill) {
    return new Response('Not found\n', {
      status: 404,
      headers: {
        'Content-Type': 'text/plain; charset=utf-8',
      },
    });
  }

  const localDocument = await getLocalSkillDocument(skill.skillPath);
  if (!localDocument) {
    return new Response('No local SKILL.md available for this skill.\n', {
      status: 404,
      headers: {
        'Content-Type': 'text/plain; charset=utf-8',
      },
    });
  }

  return new Response(localDocument.markdown, {
    status: 200,
    headers: {
      'Content-Type': 'text/markdown; charset=utf-8',
      'Cache-Control': 'no-store',
    },
  });
}
