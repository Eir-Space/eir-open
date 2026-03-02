import { describe, it, before, after } from 'node:test';
import * as assert from 'node:assert/strict';
import * as fs from 'node:fs';
import * as path from 'node:path';
import * as os from 'node:os';
import { loadSkill, loadSkillDirectory, getSkillsForMode, buildSkillPrompt } from './loader.js';
import { parseSkillMarkdown } from './parser.js';

describe('parseSkillMarkdown', () => {
  it('parses frontmatter and body', () => {
    const content = `---
name: test-skill
description: A test skill
modes: [triage, consult]
languages: [en]
---

# Test Skill

This is the prompt body.
`;
    const result = parseSkillMarkdown(content);
    assert.equal(result.meta.name, 'test-skill');
    assert.equal(result.meta.description, 'A test skill');
    assert.deepEqual(result.meta.modes, ['triage', 'consult']);
    assert.ok(result.body.includes('# Test Skill'));
    assert.ok(result.body.includes('This is the prompt body.'));
  });

  it('handles content without frontmatter', () => {
    const content = '# Just a prompt\n\nNo frontmatter here.';
    const result = parseSkillMarkdown(content);
    assert.equal(result.meta.name, 'unknown');
    assert.ok(result.body.includes('Just a prompt'));
  });

  it('handles multi-line array frontmatter', () => {
    const content = `---
name: multi-mode
modes:
  - triage
  - consult
  - review
---

Body text.
`;
    const result = parseSkillMarkdown(content);
    assert.equal(result.meta.name, 'multi-mode');
    assert.deepEqual(result.meta.modes, ['triage', 'consult', 'review']);
  });
});

describe('loadSkill', () => {
  let tmpDir: string;

  before(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'skill-kit-test-'));
  });

  after(() => {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  it('loads a skill from SKILL.md', () => {
    const skillDir = path.join(tmpDir, 'my-skill');
    fs.mkdirSync(skillDir, { recursive: true });
    fs.writeFileSync(path.join(skillDir, 'SKILL.md'), `---
name: my-skill
description: My test skill
modes: [triage]
languages: [en]
---

You are a helpful skill for triage.
`);

    const skill = loadSkill(skillDir);
    assert.ok(skill, 'Skill should be loaded');
    assert.equal(skill.meta.name, 'my-skill');
    assert.equal(skill.meta.description, 'My test skill');
    assert.deepEqual(skill.meta.modes, ['triage']);
    assert.ok(skill.prompts['default']?.includes('helpful skill for triage'));
    assert.ok(skill.prompts['en']?.includes('helpful skill for triage'));
    assert.equal(skill.path, skillDir);
  });

  it('loads a skill from skill.json', () => {
    const skillDir = path.join(tmpDir, 'json-skill');
    fs.mkdirSync(skillDir, { recursive: true });
    fs.writeFileSync(path.join(skillDir, 'skill.json'), JSON.stringify({
      name: 'json-skill',
      description: 'A JSON-based skill',
      modes: ['consult'],
    }));
    fs.writeFileSync(path.join(skillDir, 'SKILL.en.md'), 'English prompt content');

    const skill = loadSkill(skillDir);
    assert.ok(skill, 'Skill should be loaded');
    assert.equal(skill.meta.name, 'json-skill');
    assert.ok(skill.prompts['en']?.includes('English prompt content'));
    assert.ok(skill.prompts['default']?.includes('English prompt content'));
  });

  it('returns null for empty directory', () => {
    const emptyDir = path.join(tmpDir, 'empty');
    fs.mkdirSync(emptyDir, { recursive: true });
    const skill = loadSkill(emptyDir);
    assert.equal(skill, null);
  });
});

describe('loadSkillDirectory', () => {
  let tmpDir: string;

  before(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'skill-kit-dir-test-'));

    // Create two skills
    const skill1 = path.join(tmpDir, 'skill-a');
    fs.mkdirSync(skill1);
    fs.writeFileSync(path.join(skill1, 'SKILL.md'), `---
name: skill-a
modes: [triage]
---

Skill A prompt.
`);

    const skill2 = path.join(tmpDir, 'skill-b');
    fs.mkdirSync(skill2);
    fs.writeFileSync(path.join(skill2, 'SKILL.md'), `---
name: skill-b
modes: [consult]
---

Skill B prompt.
`);
  });

  after(() => {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  it('loads all skills from a directory', () => {
    const skills = loadSkillDirectory(tmpDir);
    assert.equal(skills.size, 2);
    assert.ok(skills.has('skill-a'));
    assert.ok(skills.has('skill-b'));
  });

  it('filters skills by mode', () => {
    const skills = loadSkillDirectory(tmpDir);
    const triageSkills = getSkillsForMode(skills, 'triage');
    assert.equal(triageSkills.length, 1);
    assert.equal(triageSkills[0].meta.name, 'skill-a');
  });

  it('returns empty map for nonexistent directory', () => {
    const skills = loadSkillDirectory('/nonexistent/path');
    assert.equal(skills.size, 0);
  });
});

describe('buildSkillPrompt', () => {
  it('combines prompts from multiple skills', () => {
    const skills = [
      { meta: { name: 'a', modes: [], requiredTools: [], languages: ['en'] }, prompts: { default: 'Prompt A', en: 'Prompt A' }, path: '/a' },
      { meta: { name: 'b', modes: [], requiredTools: [], languages: ['en'] }, prompts: { default: 'Prompt B', en: 'Prompt B' }, path: '/b' },
    ];
    const combined = buildSkillPrompt(skills, 'en');
    assert.ok(combined.includes('Prompt A'));
    assert.ok(combined.includes('Prompt B'));
    assert.ok(combined.indexOf('Prompt A') < combined.indexOf('Prompt B'));
  });

  it('falls back to default language', () => {
    const skills = [
      { meta: { name: 'a', modes: [], requiredTools: [], languages: ['en'] }, prompts: { default: 'Default prompt' }, path: '/a' },
    ];
    const result = buildSkillPrompt(skills, 'fr');
    assert.equal(result, 'Default prompt');
  });
});
