import { execFileSync, spawnSync } from 'node:child_process';

export function run(cmd, args, options = {}) {
  return execFileSync(cmd, args, {
    stdio: options.stdio ?? 'inherit',
    cwd: options.cwd,
    env: options.env ?? process.env,
    encoding: options.encoding,
  });
}

export function runCapture(cmd, args, options = {}) {
  const result = spawnSync(cmd, args, {
    cwd: options.cwd,
    env: options.env ?? process.env,
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  if (result.status !== 0) {
    throw new Error(
      `${cmd} ${args.join(' ')} failed (exit ${result.status}):\n${result.stderr}`
    );
  }
  return result.stdout;
}
