import { test } from 'node:test';
import assert from 'node:assert/strict';
import { repoRoot, packagesDir, luxvimPackageDir, runtimePackageDir, platformTriple } from '../lib/paths.mjs';

test('platformTriple: darwin/arm64 → darwin-arm64', () => {
  assert.equal(platformTriple('darwin', 'arm64'), 'darwin-arm64');
});

test('platformTriple: linux/x64 → linux-x64', () => {
  assert.equal(platformTriple('linux', 'x64'), 'linux-x64');
});

test('repoRoot: ends with no trailing slash', () => {
  const r = repoRoot();
  assert.equal(r.endsWith('/'), false);
  assert.equal(typeof r, 'string');
  assert.ok(r.length > 1);
});

test('packagesDir: repoRoot + /packages', () => {
  const r = repoRoot();
  assert.equal(packagesDir(), `${r}/packages`);
});

test('luxvimPackageDir: packages + /luxvim', () => {
  assert.equal(luxvimPackageDir(), `${packagesDir()}/luxvim`);
});

test('runtimePackageDir: packages + /runtime-<triple>', () => {
  assert.equal(runtimePackageDir('darwin-arm64'), `${packagesDir()}/runtime-darwin-arm64`);
});
