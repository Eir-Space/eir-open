# Contributing to eir-open

Thank you for your interest in contributing to eir-open. Whether you are fixing a bug, adding a feature, improving documentation, or reporting an issue, every contribution is welcome and valued.

This guide covers the full project. Individual sub-projects may have their own contributing guides with additional details:

- [Open Medical Scribe](apps/open-medical-scribe/CONTRIBUTING.md)
- [Health.md Standard](open-health-standard/health-md-standard/CONTRIBUTING.md)

---

## Table of Contents

1. [Code of Conduct](#code-of-conduct)
2. [Project Structure](#project-structure)
3. [Getting Started](#getting-started)
4. [How to Contribute](#how-to-contribute)
5. [Code Style](#code-style)
6. [Commit Messages](#commit-messages)
7. [Review Process](#review-process)
8. [Privacy and Security](#privacy-and-security)

---

## Code of Conduct

All participants in this project are expected to follow our [Code of Conduct](CODE_OF_CONDUCT.md). Please read it before contributing.

---

## Project Structure

```
eir-open/
  agent-harness/           # Core npm packages (TypeScript monorepo)
    packages/
      agent-core/          #   Tool loop, LLM provider abstraction, mode router
      skill-kit/           #   Skill format, loader, prompt assembly
      health-memory/       #   Health memory schemas and store interface
    examples/              #   Working examples (minimal-agent, express-agent)
  apps/                    # Applications
    eir-open-apps/         #   macOS desktop app + Chrome extension
    eir-provider-directory/#   Healthcare provider discovery (Cloudflare Workers)
    open-medical-scribe/   #   AI medical documentation (Electron + web)
    skills-eir-space/      #   Web UI for skills browsing
    skills-eir-cli/        #   CLI for skills development
  skills/                  # Reusable health skills
    swedish-medications/   #   FASS medication lookup
    us-medications/        #   FDA medication lookup
  open-health-standard/    # EIR Health Data Standard (YAML-based)
  cli/                     # Interactive installer
  site/                    # Documentation site (Astro + Starlight)
```

---

## Getting Started

### Prerequisites

- **Node.js >= 18** (Node.js >= 22 for Open Medical Scribe)
- **npm**
- **Git**

### Setup

1. **Fork** the repository on GitHub.

2. **Clone** your fork locally:

   ```bash
   git clone https://github.com/<your-username>/eir-open.git
   cd eir-open
   ```

3. **Build and test the agent-harness packages** (the core of the project):

   ```bash
   cd agent-harness
   npm ci
   npm run build
   npm run typecheck
   npm test
   ```

4. **For app development**, see the README in the specific app directory (e.g., `apps/open-medical-scribe/README.md`).

---

## How to Contribute

### Reporting Bugs

Open a GitHub issue using the **Bug Report** template. Include:

- A clear description of the problem
- Steps to reproduce
- Expected vs. actual behavior
- Environment details (Node.js version, OS, relevant provider info)

### Suggesting Features

Before writing code for a new feature, **open an issue first** to discuss it. Describe the problem you are trying to solve, alternatives you considered, and how the feature fits into the project.

### Submitting Pull Requests

1. **Create a feature branch** from `main`:

   ```bash
   git checkout -b my-feature
   ```

2. **Make your changes.** Write clear, focused commits.

3. **Add or update tests** for any new functionality.

4. **Run the checks** to make sure nothing is broken:

   ```bash
   cd agent-harness
   npm run build
   npm run typecheck
   npm test
   ```

5. **Push** your branch and open a Pull Request against `main`. In the PR description, explain what the change does and why. Reference any related issues (e.g., "Closes #42").

---

## Code Style

### TypeScript (agent-harness packages)

- **Strict mode** is enabled (`"strict": true` in tsconfig)
- **Zod** for runtime validation at package boundaries
- **Minimal dependencies** — think twice before adding a new npm package
- **Interface-driven design** — prefer abstractions (e.g., `LlmProvider`, `HealthMemoryStore`) over concrete implementations
- **Node.js built-in test runner** (`node:test`) — no external test framework needed

### General

- **ES modules** — use `import` / `export`
- **Async/await** — prefer over raw Promises or callbacks
- **Descriptive names** — use clear, self-documenting function and variable names
- **Factory functions over classes** — match existing patterns in each sub-project
- Match the style of the file you are editing

---

## Commit Messages

Write commit messages in the **imperative mood** (as if completing the sentence "This commit will ..."). Keep the subject line under 72 characters and add a body when the change warrants further explanation.

**Good examples:**

```
Add retry logic to ChatCompletionsProvider

Wrap provider calls with exponential backoff to handle transient
API failures gracefully.
```

```
Fix skill loader fallback for legacy skill.json format
```

**Avoid** vague messages like "fix stuff", "update code", or "wip".

---

## Review Process

All pull requests are reviewed by maintainers before being merged.

- **Turnaround** — maintainers review PRs as time allows. Please be patient.
- **Feedback** — you may be asked to make changes. This is normal and constructive.
- **CI checks** — all tests, type checks, and lint checks must pass before merge.
- **Scope** — smaller, focused PRs are easier to review and more likely to be merged quickly. Consider splitting large changes into multiple PRs.

---

## Privacy and Security

eir-open handles health-related data. All contributors must follow these rules:

- **Never commit real patient data** to the repository
- **Use synthetic or anonymous data** for all examples and tests
- **Review your PRs carefully** for accidental PII inclusion
- **Follow HIPAA/GDPR principles** even for test data
- **Report security vulnerabilities** privately via the process described in [SECURITY.md](SECURITY.md) — do not open public issues for security bugs

---

Thank you for helping make eir-open better. If you have questions not covered here, feel free to open a discussion or issue on GitHub.
