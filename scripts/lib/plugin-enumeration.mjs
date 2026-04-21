import fs from 'node:fs';
import path from 'node:path';
import { runCapture } from './shell.mjs';
import { repoRoot, luxvimPackageDir } from './paths.mjs';

export function parseEnumerationOutput(raw) {
  const lines = raw.trim().split('\n');
  const jsonLine = lines[lines.length - 1];
  try {
    const parsed = JSON.parse(jsonLine);
    if (!Array.isArray(parsed)) throw new Error('expected array');
    return parsed;
  } catch (err) {
    throw new Error(`Failed to parse enumeration output as JSON: ${err.message}`);
  }
}

export function readLockfile(lockfilePath) {
  return JSON.parse(fs.readFileSync(lockfilePath, 'utf8'));
}

export function joinWithLockfile(specs, lockfile) {
  return specs.map((s) => {
    const key = s.lockfile_name || s.name;
    const entry = lockfile[key];
    if (!entry || !entry.commit) {
      throw new Error(`No lockfile entry for plugin "${key}"`);
    }
    return { ...s, commit: entry.commit, branch: entry.branch ?? null };
  });
}

export function enumerate() {
  const helper = path.join(repoRoot(), 'scripts', 'helpers', 'enumerate-specs.lua');
  const raw = runCapture(
    'nvim',
    ['--headless', '-c', `luafile ${helper}`, '-c', 'qa!'],
    { cwd: repoRoot() }
  );
  const specs = parseEnumerationOutput(raw);

  const lockfile = readLockfile(path.join(luxvimPackageDir(), 'lazy-lock.json'));
  return joinWithLockfile(specs, lockfile);
}
