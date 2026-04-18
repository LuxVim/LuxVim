const SUPPORTED = Object.freeze([
  'darwin-arm64',
  'darwin-x64',
  'linux-arm64',
  'linux-x64',
  'win32-x64',
]);

export function resolveRuntimePackageName(platform, arch) {
  return `@josstei/luxvim-runtime-${platform}-${arch}`;
}

export function isSupportedPlatform(platform, arch) {
  return SUPPORTED.includes(`${platform}-${arch}`);
}

export function buildUnsupportedPlatformMessage(platform, arch) {
  return (
    `No LuxVim runtime available for ${platform}/${arch}.\n` +
    `Supported: ${SUPPORTED.join(', ')}.\n` +
    `If you installed with --no-optional or --omit=optional, reinstall without those flags.\n`
  );
}
