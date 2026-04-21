import { test } from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import { buildLauncherEnv } from '../../bin/lib/launcher-env.js';

test('buildLauncherEnv: sets NVIM_APPNAME=LuxVim', () => {
  const env = buildLauncherEnv({
    platform: 'darwin',
    base: {},
    luxvimRoot: '/pkg/luxvim',
    runtimeRoot: '/pkg/runtime',
  });
  assert.equal(env.NVIM_APPNAME, 'LuxVim');
});

test('buildLauncherEnv: sets LUXVIM_ROOT and LUXVIM_RUNTIME', () => {
  const env = buildLauncherEnv({
    platform: 'linux',
    base: {},
    luxvimRoot: '/pkg/luxvim',
    runtimeRoot: '/pkg/runtime',
  });
  assert.equal(env.LUXVIM_ROOT, '/pkg/luxvim');
  assert.equal(env.LUXVIM_RUNTIME, '/pkg/runtime');
});

test('buildLauncherEnv: prepends fzf dir to PATH (unix)', () => {
  const env = buildLauncherEnv({
    platform: 'linux',
    base: { PATH: '/usr/bin:/bin' },
    luxvimRoot: '/pkg/luxvim',
    runtimeRoot: '/pkg/runtime',
  });
  assert.equal(env.PATH, `/pkg/runtime/fzf/bin${path.delimiter}/usr/bin:/bin`);
});

test('buildLauncherEnv: prepends fzf dir to Path (windows)', () => {
  const env = buildLauncherEnv({
    platform: 'win32',
    base: { Path: 'C:\\Windows\\System32' },
    luxvimRoot: 'C:\\pkg\\luxvim',
    runtimeRoot: 'C:\\pkg\\runtime',
  });
  const expected = `C:\\pkg\\runtime\\fzf\\bin${path.delimiter}C:\\Windows\\System32`;
  assert.equal(env.Path, expected);
});

test('buildLauncherEnv: preserves other env keys', () => {
  const env = buildLauncherEnv({
    platform: 'linux',
    base: { HOME: '/home/user', LANG: 'en_US.UTF-8' },
    luxvimRoot: '/pkg/luxvim',
    runtimeRoot: '/pkg/runtime',
  });
  assert.equal(env.HOME, '/home/user');
  assert.equal(env.LANG, 'en_US.UTF-8');
});

test('buildLauncherEnv: does not set XDG_* overrides', () => {
  const env = buildLauncherEnv({
    platform: 'linux',
    base: {},
    luxvimRoot: '/pkg/luxvim',
    runtimeRoot: '/pkg/runtime',
  });
  assert.equal(env.XDG_DATA_HOME, undefined);
  assert.equal(env.XDG_CONFIG_HOME, undefined);
  assert.equal(env.XDG_CACHE_HOME, undefined);
  assert.equal(env.XDG_STATE_HOME, undefined);
});
