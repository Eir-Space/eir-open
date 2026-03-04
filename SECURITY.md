# Security Policy

## Reporting a Vulnerability

If you discover a security issue in eir-open, please report it privately. **Do not open a public GitHub issue.**

Email: **licensing@eir.space**

Include as much detail as possible:

- Description of the issue
- Steps to reproduce
- Affected component(s) and version(s)
- Potential impact

## Response Timeline

- **Acknowledgment** within 3 business days
- **Initial assessment** within 10 business days
- **Fix or mitigation plan** communicated as soon as practical

## Supported Versions

Security fixes are applied to the latest release of each published package:

| Package                 | Supported |
| ----------------------- | --------- |
| @eir-open/agent-core    | Latest    |
| @eir-open/skill-kit     | Latest    |
| @eir-open/health-memory | Latest    |

Older versions do not receive backported fixes.

## Scope

The following are in scope for security reports:

- Vulnerabilities in published npm packages (agent-harness)
- Issues in the EIR data format that could lead to data exposure
- Authentication or authorization flaws in any application
- Dependency vulnerabilities with a known exploit

Out of scope:

- Issues in third-party dependencies without a proof of concept
- Social engineering
- Denial of service without a practical attack vector

## Disclosure Policy

We follow coordinated disclosure. Once a fix is released, we will:

1. Publish a GitHub Security Advisory
2. Credit the reporter (unless they prefer to remain anonymous)
3. Include details in the next release changelog

Thank you for helping keep eir-open and its users safe.
