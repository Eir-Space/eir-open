import { defineCollection, z } from 'astro:content';

const docs = defineCollection({
  type: 'content',
  schema: z.object({
    title: z.string(),
    description: z.string(),
    sidebar: z
      .object({
        order: z.number().optional(),
      })
      .optional(),
  }),
});

const blog = defineCollection({
  type: 'content',
  schema: z.object({
    title: z.string(),
    description: z.string(),
    pubDate: z.coerce.date(),
    author: z.string().default('Eir Open'),
    tags: z.array(z.string()).default([]),
    featured: z.boolean().optional(),
    draft: z.boolean().optional(),
  }),
});

export const collections = {
  docs,
  blog,
};
