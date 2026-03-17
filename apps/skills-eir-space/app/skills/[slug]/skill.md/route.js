import { getSkillBySlug, getSkillDocument } from '@/lib/skill-store';

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

  const document = await getSkillDocument(skill);
  if (!document) {
    return new Response('No SKILL.md available for this skill.\n', {
      status: 404,
      headers: {
        'Content-Type': 'text/plain; charset=utf-8',
      },
    });
  }

  return new Response(document.markdown, {
    status: 200,
    headers: {
      'Content-Type': 'text/markdown; charset=utf-8',
      'Cache-Control': 'no-store',
    },
  });
}
