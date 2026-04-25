#!/usr/bin/env node
import { execFileSync } from 'node:child_process';
import path from 'node:path';
import process from 'node:process';
import { createRequire } from 'node:module';
import {
  resolveRuntimePackageName,
  buildUnsupportedPlatformMessage,
} from './lib/runtime-resolver.js';
import { buildLauncherEnv } from './lib/launcher-env.js';

const require = createRequire(import.meta.url);
const { platform, arch } = process;
const runtimePkg = resolveRuntimePackageName(platform, arch);

let runtimeRoot;
try {
  runtimeRoot = path.dirname(require.resolve(`${runtimePkg}/package.json`));
} catch {
  process.stderr.write(buildUnsupportedPlatformMessage(platform, arch));
  process.exit(1);
}

const luxvimRoot = path.dirname(require.resolve('@josstei/luxvim/package.json'));
const nvimBin = path.join(
  runtimeRoot, 'neovim', 'bin',
  platform === 'win32' ? 'nvim.exe' : 'nvim'
);

const env = buildLauncherEnv({
  platform,
  base: process.env,
  luxvimRoot,
  runtimeRoot,
});

execFileSync(
  nvimBin,
  [
    '--cmd', `set rtp^=${luxvimRoot}`,
    '-u', path.join(luxvimRoot, 'init.lua'),
    ...process.argv.slice(2),
  ],
  { stdio: 'inherit', env }
);
