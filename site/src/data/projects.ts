export interface Project {
  title: string;
  description: string;
  slug: string;
  icon: string;
  tags: string[];
  category: 'library' | 'app';
}

export const projects: Project[] = [
  {
    title: 'EIR Health Data Standard',
    description:
      'Open YAML-based standard for structuring healthcare information optimized for LLMs. Privacy-first, MCP-compatible.',
    slug: 'health-md-standard',
    icon: 'file-heart',
    tags: ['YAML', 'MCP', 'pip'],
    category: 'library',
  },
  {
    title: 'US FDA Medications',
    description:
      'Comprehensive US FDA medication lookup with 81,212 medications. CLI, JavaScript API, and drug interaction checking.',
    slug: 'us-medications',
    icon: 'pill',
    tags: ['npm', 'CLI', 'OpenClaw'],
    category: 'library',
  },
  {
    title: 'Swedish Medications',
    description:
      'Complete Swedish pharmaceutical database from FASS. 9,064 medications with brand-to-substance mapping and AI-agent support.',
    slug: 'swedish-medications',
    icon: 'pill',
    tags: ['npm', 'CLI', 'OpenClaw'],
    category: 'library',
  },
  {
    title: 'CBT Programs Registry',
    description:
      'Open modular CBT program registry with multilingual locales, provenance labels, and CLI tooling for recommendation and improvement.',
    slug: 'cbt-programs',
    icon: 'brain',
    tags: ['npm', 'CLI', 'Multilingual'],
    category: 'library',
  },
  {
    title: 'Agent Core',
    description:
      'Tool loop engine, LLM provider abstraction, mode routing, and context building for health AI agents.',
    slug: 'agent-harness/agent-core',
    icon: 'cpu',
    tags: ['npm', 'TypeScript'],
    category: 'library',
  },
  {
    title: 'Skill Kit',
    description:
      'Unified skill format using Markdown + YAML frontmatter, with loader and prompt assembly utilities.',
    slug: 'agent-harness/skill-kit',
    icon: 'book-open',
    tags: ['npm', 'TypeScript'],
    category: 'library',
  },
  {
    title: 'Health Memory',
    description:
      'Open standard for health agent memory with schemas, store interface, and reference implementation.',
    slug: 'agent-harness/health-memory',
    icon: 'brain',
    tags: ['npm', 'TypeScript'],
    category: 'library',
  },
  {
    title: 'Eir Open Apps',
    description:
      'Privacy-first apps for Swedish medical records. macOS and iOS apps with AI chat, Chrome extension for one-click export.',
    slug: 'eir-open-apps',
    icon: 'smartphone',
    tags: ['macOS', 'iOS', 'Chrome'],
    category: 'app',
  },
  {
    title: 'Open Medical Scribe',
    description:
      'AI medical scribe with real-time transcription and structured note generation. Runs fully local for maximum privacy.',
    slug: 'open-medical-scribe',
    icon: 'mic',
    tags: ['Electron', 'Whisper', 'Local'],
    category: 'app',
  },
  {
    title: 'EIR Provider Directory',
    description:
      'Production-grade Swedish provider discovery with map/list UX, verified self-referral status, and Cloudflare D1/R2 data infrastructure.',
    slug: 'eir-provider-directory',
    icon: 'map-pinned',
    tags: ['Cloudflare', 'D1', 'R2'],
    category: 'app',
  },
];

export const libraryProjects = projects.filter((p) => p.category === 'library');
export const appProjects = projects.filter((p) => p.category === 'app');
