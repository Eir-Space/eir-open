import { describe, it } from 'node:test';
import * as assert from 'node:assert/strict';
import { buildToolsFromSkills } from './toolBuilder.js';
import type { LoadedSkill } from './types.js';

function makeSkill(name: string, scripts: LoadedSkill['scripts'] = []): LoadedSkill {
  return {
    meta: { name, description: `${name} skill`, modes: [], requiredTools: [], languages: ['en'], scripts: [] },
    prompts: { default: `Prompt for ${name}` },
    path: `/skills/${name}`,
    scripts,
  };
}

describe('buildToolsFromSkills', () => {
  it('creates tool definitions from skills with scripts', () => {
    const skills = [makeSkill('analyzer', [
      { name: 'run', entrypoint: '/scripts/run.js', description: 'Run analysis' },
      { name: 'check', entrypoint: '/scripts/check.js' },
    ])];

    const result = buildToolsFromSkills(skills);
    assert.equal(result.definitions.length, 2);
    assert.equal(result.definitions[0].function.name, 'analyzer__run');
    assert.equal(result.definitions[1].function.name, 'analyzer__check');
    assert.ok(result.handlers['analyzer__run']);
    assert.ok(result.handlers['analyzer__check']);
  });

  it('returns empty set for skills with no scripts', () => {
    const skills = [makeSkill('no-scripts')];
    const result = buildToolsFromSkills(skills);
    assert.equal(result.definitions.length, 0);
    assert.deepEqual(result.handlers, {});
  });

  it('uses script description if provided', () => {
    const skills = [makeSkill('s', [
      { name: 'run', entrypoint: '/x.js', description: 'Custom description' },
    ])];
    const result = buildToolsFromSkills(skills);
    assert.equal(result.definitions[0].function.description, 'Custom description');
  });

  it('falls back to default description format', () => {
    const skills = [makeSkill('myskill', [
      { name: 'execute', entrypoint: '/x.js' },
    ])];
    const result = buildToolsFromSkills(skills);
    assert.ok(result.definitions[0].function.description.includes('execute'));
    assert.ok(result.definitions[0].function.description.includes('myskill'));
  });

  it('uses script parameters if provided', () => {
    const customParams = {
      type: 'object',
      properties: { input: { type: 'string' }, count: { type: 'number' } },
      required: ['input'],
    };
    const skills = [makeSkill('s', [
      { name: 'run', entrypoint: '/x.js', parameters: customParams },
    ])];
    const result = buildToolsFromSkills(skills);
    assert.deepEqual(result.definitions[0].function.parameters, customParams);
  });

  it('falls back to default query parameter', () => {
    const skills = [makeSkill('s', [
      { name: 'run', entrypoint: '/x.js' },
    ])];
    const result = buildToolsFromSkills(skills);
    const params = result.definitions[0].function.parameters as Record<string, unknown>;
    assert.equal(params.type, 'object');
    assert.ok((params.properties as Record<string, unknown>).query);
  });

  it('handles multiple skills each with multiple scripts', () => {
    const skills = [
      makeSkill('skill-a', [
        { name: 'run', entrypoint: '/a/run.js' },
        { name: 'check', entrypoint: '/a/check.js' },
      ]),
      makeSkill('skill-b', [
        { name: 'analyze', entrypoint: '/b/analyze.js' },
        { name: 'report', entrypoint: '/b/report.js' },
      ]),
    ];
    const result = buildToolsFromSkills(skills);
    assert.equal(result.definitions.length, 4);
    const names = result.definitions.map(d => d.function.name);
    assert.ok(names.includes('skill-a__run'));
    assert.ok(names.includes('skill-a__check'));
    assert.ok(names.includes('skill-b__analyze'));
    assert.ok(names.includes('skill-b__report'));
  });
});
