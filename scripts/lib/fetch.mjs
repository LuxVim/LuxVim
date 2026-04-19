import fs from 'node:fs';
import path from 'node:path';
import { pipeline } from 'node:stream/promises';
import { Readable } from 'node:stream';
import { run } from './shell.mjs';

export async function downloadToFile(url, destFile, { token } = {}) {
  const headers = token ? { Authorization: `Bearer ${token}` } : {};
  const response = await fetch(url, { headers, redirect: 'follow' });
  if (!response.ok) {
    throw new Error(`GET ${url} failed: ${response.status} ${response.statusText}`);
  }
  await fs.promises.mkdir(path.dirname(destFile), { recursive: true });
  const file = fs.createWriteStream(destFile);
  await pipeline(Readable.fromWeb(response.body), file);
  return destFile;
}

export function extractTarGz(tarPath, destDir, { stripComponents = 0 } = {}) {
  fs.mkdirSync(destDir, { recursive: true });
  const args = ['-xzf', tarPath, '-C', destDir];
  if (stripComponents > 0) {
    args.push(`--strip-components=${stripComponents}`);
  }
  run('tar', args);
}

export function extractZip(zipPath, destDir) {
  fs.mkdirSync(destDir, { recursive: true });
  run('unzip', ['-q', '-o', zipPath, '-d', destDir]);
}
