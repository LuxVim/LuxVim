import path from 'node:path';

export function buildLauncherEnv({ platform, base, luxvimRoot, runtimeRoot }) {
  const env = { ...base };
  env.NVIM_APPNAME = 'LuxVim';
  env.LUXVIM_ROOT = luxvimRoot;
  env.LUXVIM_RUNTIME = runtimeRoot;

  const pathLib = platform === 'win32' ? path.win32 : path.posix;
  const fzfDir = pathLib.join(runtimeRoot, 'fzf', 'bin');
  const pathKey = platform === 'win32' ? 'Path' : 'PATH';
  const existing = env[pathKey] ?? '';
  env[pathKey] = `${fzfDir}${path.delimiter}${existing}`;

  return env;
}
