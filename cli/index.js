#!/usr/bin/env node

import { execSync, spawn } from "node:child_process";
import { existsSync } from "node:fs";
import { homedir, platform } from "node:os";
import { join } from "node:path";
import { Command } from "commander";
import * as p from "@clack/prompts";
import chalk from "chalk";

const VERSION = "1.0.0";
const DOCS_URL = "https://eir-space.github.io/eir-open/docs/quickstart/";
const OPENCLAW_DOCS = "https://eir-space.github.io/eir-open/docs/openclaw-integration/";
const VIEWER_DMG = "https://github.com/BirgerMoell/eir-open-apps/releases/latest/download/EirViewer-macOS.dmg";
const VIEWER_RELEASES = "https://github.com/BirgerMoell/eir-open-apps/releases/latest";

// ── Brand palette (EIR Serenity, from site/src/styles/global.css) ───────────

const EIR_PALETTE = {
  accent: "#1e5f6d",
  accentBright: "#2a7a8a",
  accentDim: "#1a6a7a",
  info: "#7fb3bf",
  success: "#2FBF71",
  warn: "#e8a830",
  error: "#ef4444",
  muted: "#4a7c8a",
};

const theme = {
  accent: chalk.hex(EIR_PALETTE.accent),
  accentBright: chalk.hex(EIR_PALETTE.accentBright),
  accentDim: chalk.hex(EIR_PALETTE.accentDim),
  info: chalk.hex(EIR_PALETTE.info),
  success: chalk.hex(EIR_PALETTE.success),
  warn: chalk.hex(EIR_PALETTE.warn),
  muted: chalk.hex(EIR_PALETTE.muted),
  heading: chalk.bold.hex(EIR_PALETTE.accent),
};

// ── ASCII banner (same ▄░█▀ charset as openclaw, Warp-safe) ────────────────

const BANNER_WIDTH = 50;

const EIR_ASCII = [
  " ███████ ██ ██████   ██████  ██████  ███████ ███    ██",
  " ██      ██ ██   ██ ██    ██ ██   ██ ██      ████   ██",
  " █████   ██ ██████  ██    ██ ██████  █████   ██ ██  ██",
  " ██      ██ ██   ██ ██    ██ ██      ██      ██  ██ ██",
  " ███████ ██ ██   ██  ██████  ██      ███████ ██   ████",
];

function printBanner() {
  if (!process.stdout.isTTY) return;
  if (chalk.level === 0) {
    console.log(`\n${EIR_ASCII.join("\n")}\n`);
    return;
  }

  const colored = EIR_ASCII.map((line) =>
    Array.from(line)
      .map((ch) => (ch === "\u2588" ? theme.accentBright(ch) : theme.muted(ch)))
      .join("")
  );

  console.log(`\n${colored.join("\n")}\n`);
}

const TITLE = "Eir Open -- AI-powered health empowerment";

// ── Terminal restoration (matches openclaw's restore.ts) ────────────────────

const RESET_SEQUENCE =
  "\x1b[0m" +     // reset attributes
  "\x1b[?25h" +   // show cursor
  "\x1b[?1000l" + // disable mouse tracking
  "\x1b[?1002l" + // disable cell-motion mouse tracking
  "\x1b[?1003l" + // disable all-motion mouse tracking
  "\x1b[?1006l" + // disable SGR mouse mode
  "\x1b[?2004l";  // disable bracketed paste

function restoreTerminal() {
  const stdin = process.stdin;
  if (stdin.isTTY && typeof stdin.setRawMode === "function") {
    try { stdin.setRawMode(false); } catch { /* best effort */ }
  }
  if (process.stdout.isTTY) {
    try { process.stdout.write(RESET_SEQUENCE); } catch { /* best effort */ }
  }
}

function exit(code) {
  restoreTerminal();
  process.exit(code);
}

process.on("exit", restoreTerminal);
process.on("SIGINT", () => { restoreTerminal(); process.exit(130); });
process.on("SIGTERM", () => { restoreTerminal(); process.exit(143); });

// ── Text wrapping (matches openclaw's note.ts) ─────────────────────────────

function visibleWidth(str) {
  return Array.from(str.replace(/\x1b\[[0-9;]*m/g, "")).length;
}

function isCopySensitive(word) {
  if (/^https?:\/\//i.test(word)) return true;
  if (word.startsWith("/") || word.startsWith("~/") || word.startsWith("./")) return true;
  if (word.includes("/") || word.includes("\\")) return true;
  return false;
}

function wrapLine(line, maxWidth) {
  if (line.trim().length === 0) return [line];

  const match = line.match(/^(\s*)([-*]\s+)?(.*)$/);
  const indent = match?.[1] ?? "";
  const bullet = match?.[2] ?? "";
  const content = match?.[3] ?? "";
  const firstPrefix = `${indent}${bullet}`;
  const nextPrefix = `${indent}${bullet ? " ".repeat(bullet.length) : ""}`;
  const firstWidth = Math.max(10, maxWidth - visibleWidth(firstPrefix));
  const nextWidth = Math.max(10, maxWidth - visibleWidth(nextPrefix));

  const words = content.split(/\s+/).filter(Boolean);
  const lines = [];
  let current = "";
  let prefix = firstPrefix;
  let available = firstWidth;

  for (const word of words) {
    if (!current) {
      current = word;
      continue;
    }
    if (visibleWidth(`${current} ${word}`) <= available) {
      current = `${current} ${word}`;
      continue;
    }
    // Never break copy-sensitive tokens (URLs, paths) across lines
    if (isCopySensitive(word) && visibleWidth(word) > available) {
      lines.push(prefix + current);
      lines.push(nextPrefix + word);
      prefix = nextPrefix;
      available = nextWidth;
      current = "";
      continue;
    }
    lines.push(prefix + current);
    prefix = nextPrefix;
    available = nextWidth;
    current = word;
  }
  if (current || words.length === 0) {
    lines.push(prefix + current);
  }
  return lines;
}

function wrapText(message) {
  const columns = process.stdout.columns ?? 80;
  const maxWidth = Math.max(40, Math.min(88, columns - 10));
  return message.split("\n").flatMap((line) => wrapLine(line, maxWidth)).join("\n");
}

// ── Async command runner (non-blocking for spinner animation) ───────────────

function runAsync(cmd, args, { verbose = false } = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn(cmd, args, {
      stdio: verbose ? "inherit" : "ignore",
    });
    child.on("close", (code) => {
      if (code === 0) resolve();
      else reject(new Error(`${cmd} exited with code ${code}`));
    });
    child.on("error", reject);
  });
}

// ── Helpers ─────────────────────────────────────────────────────────────────

function hasCmd(name) {
  try {
    execSync(`command -v ${name}`, { stdio: "ignore" });
    return true;
  } catch {
    return false;
  }
}

function parseMajorVersion(raw) {
  const match = raw.replace(/^v/, "").match(/^(\d+)/);
  return match ? Number(match[1]) : 0;
}

// ── Prerequisite checks ─────────────────────────────────────────────────────

function checkNode() {
  if (!hasCmd("node")) return { ok: false, label: "Node.js 18+ missing" };
  try {
    const ver = execSync("node -v", { encoding: "utf8" }).trim();
    const major = parseMajorVersion(ver);
    if (major < 18 || !hasCmd("npm")) return { ok: false, label: "Node.js 18+ missing" };
    return { ok: true, label: `Node.js ${ver}` };
  } catch {
    return { ok: false, label: "Node.js 18+ missing" };
  }
}

function checkPython() {
  if (hasCmd("python3")) {
    try {
      execSync("python3 -m pip --version", { stdio: "ignore" });
      return { ok: true, label: "Python 3 + pip" };
    } catch { /* fall through */ }
  }
  if (hasCmd("python")) {
    try {
      const v = execSync('python -c "import sys; print(sys.version_info.major)"', { encoding: "utf8" }).trim();
      if (v === "3") {
        execSync("python -m pip --version", { stdio: "ignore" });
        return { ok: true, label: "Python 3 + pip" };
      }
    } catch { /* fall through */ }
  }
  return { ok: false, label: "Python 3 + pip" };
}

function checkCurl() {
  return { ok: hasCmd("curl"), label: "curl" };
}

function checkXcodeCli() {
  try {
    execSync("xcode-select -p", { stdio: "ignore" });
    return { ok: true, label: "Xcode CLI Tools" };
  } catch {
    return { ok: false, label: "Xcode CLI Tools" };
  }
}

function checkBrew() {
  return { ok: hasCmd("brew"), label: "Homebrew" };
}

function checkOpenClaw() {
  return { ok: hasCmd("openclaw"), label: "OpenClaw" };
}

function runPrereqChecks({ strict = false }) {
  const checks = [
    checkNode(),
    checkPython(),
    checkCurl(),
    checkXcodeCli(),
    checkBrew(),
    checkOpenClaw(),
  ];

  for (const c of checks) {
    if (c.ok) {
      p.log.success(c.label);
    } else {
      p.log.warn(c.label);
    }
  }

  const node = checks[0];
  const python = checks[1];
  const curl = checks[2];
  if (!node.ok) p.log.info("  brew install node  (or nvm install 18)");
  if (!python.ok) p.log.info("  brew install python");

  if (strict) {
    if (!node.ok) {
      p.cancel("Node.js 18+ is required. Install it first, then re-run.");
      exit(1);
    }
    if (!curl.ok) {
      p.cancel("curl is required. Run: xcode-select --install");
      exit(1);
    }
  }

  return { node, python, curl };
}

// ── Install functions (async, non-blocking) ─────────────────────────────────

function getPipBin() {
  if (hasCmd("python3")) return "python3";
  if (hasCmd("python")) return "python";
  return null;
}

async function installMedications({ verbose, dryRun }) {
  if (dryRun) return "ok";
  if (!checkNode().ok) return "skip";
  try {
    await runAsync("npm", ["install", "-g", "swedish-medications", "us-medications"], { verbose });
    return "ok";
  } catch {
    return "fail";
  }
}

async function installHealthMd({ verbose, dryRun }) {
  if (dryRun) return "ok";
  if (!checkPython().ok) return "skip";
  const py = getPipBin();
  if (!py) return "skip";
  try {
    await runAsync(py, ["-m", "pip", "install", "health-md", "PyYAML", "beautifulsoup4"], { verbose });
    return "ok";
  } catch {
    return "fail";
  }
}

async function installEirApps({ verbose, dryRun }) {
  if (dryRun) return "ok";
  const dmgPath = join(homedir(), "Downloads", "EirViewer-macOS.dmg");
  try {
    await runAsync("curl", ["-fsSL", "-o", dmgPath, VIEWER_DMG], { verbose });
    if (existsSync(dmgPath)) {
      try { execSync(`open "${dmgPath}"`, { stdio: "ignore" }); } catch { /* ignore */ }
      return "ok";
    }
  } catch { /* fall through */ }
  try { execSync(`open "${VIEWER_RELEASES}"`, { stdio: "ignore" }); } catch { /* ignore */ }
  return "skip";
}

async function installOpenClaw({ verbose, dryRun }) {
  if (dryRun) return "ok";
  if (!hasCmd("openclaw")) return "skip";
  try { await runAsync("openclaw", ["skill", "add", "us-medications"], { verbose }); } catch { /* ignore */ }
  try { await runAsync("openclaw", ["skill", "add", "swedish-medications"], { verbose }); } catch { /* ignore */ }
  return "ok";
}

// ── Step runner (spinner-wrapped, async) ────────────────────────────────────

async function runStep(label, fn, opts) {
  if (opts.dryRun) {
    p.log.info(`[dry-run] Would: ${label}`);
    return "ok";
  }

  const s = p.spinner();
  s.start(label);
  const result = await fn(opts);
  switch (result) {
    case "ok":
      s.stop(`${label} done`);
      break;
    case "skip":
      s.stop(`${label} skipped (prerequisite missing)`);
      break;
    default:
      s.stop(`${label} failed`);
      break;
  }
  return result;
}

// ── Verify installation ─────────────────────────────────────────────────────

function verify() {
  const lines = [];
  if (hasCmd("fass-lookup")) {
    try {
      const out = execSync("fass-lookup paracetamol", { encoding: "utf8", timeout: 10000 })
        .split("\n").slice(0, 5).join("\n").trim();
      if (out) lines.push(out);
    } catch { /* ignore */ }
  }
  if (hasCmd("us-medications")) {
    try {
      const out = execSync('us-medications "lisinopril"', { encoding: "utf8", timeout: 10000 })
        .split("\n").slice(0, 5).join("\n").trim();
      if (out) lines.push(out);
    } catch { /* ignore */ }
  }
  if (lines.length > 0) {
    p.log.step("Verification");
    for (const line of lines) {
      p.log.info(wrapText(line));
    }
  }
}

// ── Dispatch ────────────────────────────────────────────────────────────────

const STEPS = [
  { key: "medications", label: "Installing medication skills", fn: installMedications },
  { key: "health-md", label: "Installing Health.md standard", fn: installHealthMd },
  { key: "eir-apps", label: "Downloading Eir Viewer", fn: installEirApps },
  { key: "openclaw", label: "Adding OpenClaw skills", fn: installOpenClaw },
];

async function runSelection(selection, opts) {
  let installedMedications = false;

  if (selection === "everything") {
    for (const step of STEPS) {
      const result = await runStep(step.label, step.fn, opts);
      if (step.key === "medications" && result === "ok") installedMedications = true;
    }
  } else {
    const step = STEPS.find((s) => s.key === selection);
    if (step) {
      const result = await runStep(step.label, step.fn, opts);
      if (step.key === "medications" && result === "ok") installedMedications = true;
    }
  }

  if (installedMedications && !opts.dryRun) {
    verify();
  }
}

// ── Main ────────────────────────────────────────────────────────────────────

const program = new Command();

program
  .name("eir-open")
  .description("Install medication skills, Health.md, Eir Apps, and OpenClaw integration")
  .version(VERSION)
  .option("--all", "Install everything (no interactive menu)")
  .option("--dry-run", "Print what would be installed without making changes")
  .option("--verbose", "Show full output from install commands")
  .addHelpText("after", `\nDocs: ${DOCS_URL}`)
  .action(async (opts) => {
    if (platform() !== "darwin") {
      p.cancel(`This installer is for macOS only. See: ${DOCS_URL}`);
      exit(1);
    }

    printBanner();
    p.intro(theme.heading(TITLE));

    const installOpts = {
      verbose: Boolean(opts.verbose),
      dryRun: Boolean(opts.dryRun),
    };

    runPrereqChecks({ strict: Boolean(opts.all) });

    if (opts.all) {
      await runSelection("everything", installOpts);
    } else {
      if (!process.stdin.isTTY) {
        p.log.error("Interactive mode requires a TTY. Use --all to install everything non-interactively.");
        exit(1);
      }

      const selection = await p.select({
        message: theme.accent("What would you like to install?"),
        options: [
          { value: "medications", label: "Medication skills", hint: theme.muted("npm install -g swedish-medications us-medications") },
          { value: "health-md", label: "Health.md standard", hint: theme.muted("pip install health-md PyYAML beautifulsoup4") },
          { value: "eir-apps", label: "Eir Open Apps", hint: theme.muted("Download EirViewer macOS app") },
          { value: "openclaw", label: "OpenClaw integration", hint: theme.muted("openclaw skill add ...") },
          { value: "everything", label: "Everything" },
        ],
      });

      if (p.isCancel(selection)) {
        p.cancel("Setup cancelled.");
        exit(0);
      }

      await runSelection(selection, installOpts);
    }

    p.log.step("Links");
    p.log.info(wrapText(`Docs:     ${DOCS_URL}`));
    p.log.info(wrapText(`OpenClaw: ${OPENCLAW_DOCS}`));

    p.outro("Done! Eir Open is ready.");
  });

program.parse();
