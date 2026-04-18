import { test } from 'node:test';
import assert from 'node:assert/strict';
import { resolveRuntimePackageName, buildUnsupportedPlatformMessage } from '../../bin/lib/runtime-resolver.js';

test('resolveRuntimePackageName: darwin/arm64', () => {
  assert.equal(
    resolveRuntimePackageName('darwin', 'arm64'),
    '@josstei/luxvim-runtime-darwin-arm64'
  );
});

test('resolveRuntimePackageName: linux/x64', () => {
  assert.equal(
    resolveRuntimePackageName('linux', 'x64'),
    '@josstei/luxvim-runtime-linux-x64'
  );
});

test('resolveRuntimePackageName: win32/x64', () => {
  assert.equal(
    resolveRuntimePackageName('win32', 'x64'),
    '@josstei/luxvim-runtime-win32-x64'
  );
});

test('buildUnsupportedPlatformMessage: names the platform and supported list', () => {
  const msg = buildUnsupportedPlatformMessage('openbsd', 'x64');
  assert.match(msg, /openbsd\/x64/);
  assert.match(msg, /darwin-arm64/);
  assert.match(msg, /linux-x64/);
  assert.match(msg, /win32-x64/);
});

test('buildUnsupportedPlatformMessage: mentions --no-optional hazard', () => {
  const msg = buildUnsupportedPlatformMessage('darwin', 'arm64');
  assert.match(msg, /--no-optional|--omit=optional/);
});
