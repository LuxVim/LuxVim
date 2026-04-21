import { test } from 'node:test';
import assert from 'node:assert/strict';
import { parseEnumerationOutput, joinWithLockfile } from '../lib/plugin-enumeration.mjs';

test('parseEnumerationOutput: parses JSON array from last line', () => {
  const raw = `Some pre-noise\n[{"name":"nvim-tree","lockfile_name":"nvim-tree.lua","source":"nvim-tree/nvim-tree.lua","build":null}]`;
  const result = parseEnumerationOutput(raw);
  assert.equal(result.length, 1);
  assert.equal(result[0].name, 'nvim-tree');
  assert.equal(result[0].lockfile_name, 'nvim-tree.lua');
  assert.equal(result[0].source, 'nvim-tree/nvim-tree.lua');
  assert.equal(result[0].build, null);
});

test('parseEnumerationOutput: rejects non-JSON', () => {
  assert.throws(() => parseEnumerationOutput('not json'), /parse/i);
});

test('joinWithLockfile: attaches commit SHA from lockfile using lockfile_name', () => {
  const specs = [
    { name: 'nvim-tree', lockfile_name: 'nvim-tree.lua', source: 'nvim-tree/nvim-tree.lua', build: null },
    { name: 'plenary.nvim', lockfile_name: 'plenary.nvim', source: 'nvim-lua/plenary.nvim', build: null },
  ];
  const lockfile = {
    'nvim-tree.lua': { branch: 'master', commit: 'abc123' },
    'plenary.nvim': { branch: 'master', commit: 'def456' },
  };
  const result = joinWithLockfile(specs, lockfile);
  assert.equal(result.length, 2);
  assert.equal(result[0].commit, 'abc123');
  assert.equal(result[1].commit, 'def456');
});

test('joinWithLockfile: throws on missing lockfile entry', () => {
  const specs = [{ name: 'unknown', lockfile_name: 'unknown', source: 'x/unknown', build: null }];
  const lockfile = {};
  assert.throws(() => joinWithLockfile(specs, lockfile), /unknown/);
});
