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
    title: 'Eir Open Apps',
    description:
      'Privacy-first apps for Swedish medical records. macOS and iOS apps with AI chat, Chrome extension for one-click export.',
    slug: 'eir-open-apps',
    icon: 'smartphone',
    tags: ['macOS', 'iOS', 'Chrome'],
    category: 'app',
  },
];

export const libraryProjects = projects.filter((p) => p.category === 'library');
export const appProjects = projects.filter((p) => p.category === 'app');
