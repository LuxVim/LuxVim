#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import { downloadToFile, extractTarGz } from './lib/fetch.mjs';
import { enumerate } from './lib/plugin-enumeration.mjs';
import { detectSpdxId } from './lib/spdx.mjs';
import { vendorPluginsDir, repoRoot } from './lib/paths.mjs';

const STRIP_DIRS = ['.git', 'tests', 'test', '.github', 'spec', 'benchmarks'];
const LICENSE_CANDIDATES = ['LICENSE', 'LICENSE.md', 'LICENSE.txt', 'COPYING', 'UNLICENSE'];

function rmrf(p) {
  fs.rmSync(p, { recursive: true, force: true });
}

function findLicense(dir) {
  for (const name of LICENSE_CANDIDATES) {
    const p = path.join(dir, name);
    if (fs.existsSync(p)) return { path: p, name, text: fs.readFileSync(p, 'utf8') };
  }
  return null;
}

async function vendorOne(spec, tmpDir) {
  const { name, source, commit } = spec;
  const pluginDir = path.join(vendorPluginsDir(), name);
  rmrf(pluginDir);

  const tarPath = path.join(tmpDir, `${name}-${commit}.tar.gz`);
  const url = `https://codeload.github.com/${source}/tar.gz/${commit}`;
  process.stdout.write(`  Fetching ${source}@${commit.slice(0, 7)} ... `);
  await downloadToFile(url, tarPath, { token: process.env.GITHUB_TOKEN });

  fs.mkdirSync(pluginDir, { recursive: true });
  extractTarGz(tarPath, pluginDir, { stripComponents: 1 });

  for (const dir of STRIP_DIRS) {
    rmrf(path.join(pluginDir, dir));
  }

  const license = findLicense(pluginDir);
  const spdx = license ? detectSpdxId(license.text) : null;

  process.stdout.write(`${spdx ?? 'UNKNOWN'}\n`);
  return { name, source, commit, license_spdx: spdx, license_file: license?.name ?? null };
}

async function main() {
  const tmpDir = path.join(repoRoot(), 'scripts', 'tmp');
  fs.mkdirSync(tmpDir, { recursive: true });

  fs.mkdirSync(vendorPluginsDir(), { recursive: true });

  console.log('Enumerating plugin specs under headless nvim...');
  const specs = enumerate();
  console.log(`Found ${specs.length} plugins.\n`);

  const manifest = [];
  for (const spec of specs) {
    manifest.push(await vendorOne(spec, tmpDir));
  }

  const unknown = manifest.filter((m) => !m.license_spdx);
  if (unknown.length > 0) {
    console.error('\nPlugins with undetected licenses:');
    for (const m of unknown) console.error(`  ${m.name} (${m.source})`);
    console.error('\nExpect `audit-licenses.mjs` to fail until these are resolved.');
  }

  const manifestPath = path.join(vendorPluginsDir(), '.manifest.json');
  fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2) + '\n');
  console.log(`\nWrote manifest: ${manifestPath}`);

  rmrf(tmpDir);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
