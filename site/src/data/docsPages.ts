export type DocsPage = {
  slug: string;
  title: string;
  description: string;
};

export const docsPages: DocsPage[] = [
  {
    slug: '',
    title: 'Documentation',
    description: 'Overview of the main Eir Open projects, apps, and integration guides.',
  },
  {
    slug: 'quickstart',
    title: 'Quickstart',
    description: 'Installation paths and the fastest way to get Eir Open running locally.',
  },
  {
    slug: 'agent-integration',
    title: 'Agent Integration',
    description: 'How to use Eir Open tools with Claude, LangChain, MCP, and custom agents.',
  },
  {
    slug: 'mcp-server',
    title: 'MCP Server',
    description: 'Load EIR health data files into Claude Desktop and other MCP clients.',
  },
  {
    slug: 'openclaw-integration',
    title: 'OpenClaw Integration',
    description: 'Add Eir Open skills and health-data tooling to OpenClaw.',
  },
  {
    slug: 'health-md-standard',
    title: 'EIR Health Data Standard',
    description: 'Open YAML-based health format optimized for LLM comprehension and privacy.',
  },
  {
    slug: 'us-medications',
    title: 'US FDA Medications',
    description: 'US medication lookup and interaction tooling for AI agents and apps.',
  },
  {
    slug: 'swedish-medications',
    title: 'Swedish Medications',
    description: 'Swedish pharmaceutical lookup from FASS with brand and substance mapping.',
  },
  {
    slug: 'cbt-programs',
    title: 'CBT Programs Registry',
    description: 'Registry of open CBT programs with localization and provenance metadata.',
  },
  {
    slug: 'cbt-programs/viewer',
    title: 'CBT Program Viewer',
    description: 'Viewer and filter UI for CBT programs in the open registry.',
  },
  {
    slug: 'eir-open-apps',
    title: 'Eir Open Apps',
    description: 'Privacy-first apps for Swedish records and personal health workflows.',
  },
  {
    slug: 'eir-provider-directory',
    title: 'EIR Provider Directory',
    description: 'Swedish healthcare provider search with verified capability data.',
  },
  {
    slug: 'open-medical-scribe',
    title: 'Open Medical Scribe',
    description: 'Local AI scribe for transcription and note generation.',
  },
  {
    slug: 'agent-harness',
    title: 'Agent Harness',
    description: 'Toolkit for health AI agents, including tool loops, skills, and memory.',
  },
  {
    slug: 'agent-harness/agent-core',
    title: 'Agent Core',
    description: 'Core loop engine and provider abstraction for agentic workflows.',
  },
  {
    slug: 'agent-harness/skill-kit',
    title: 'Skill Kit',
    description: 'Markdown-based skill format and loader for agent systems.',
  },
  {
    slug: 'agent-harness/health-memory',
    title: 'Health Memory',
    description: 'Schemas and reference implementation for persistent health agent memory.',
  },
  {
    slug: 'contributing',
    title: 'Contributing',
    description: 'Ways to contribute code, documentation, review, and operational support.',
  },
];

export const docsPageMap = new Map(docsPages.map((page) => [page.slug, page]));
