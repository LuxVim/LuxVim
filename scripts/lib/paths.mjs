import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const SCRIPTS_LIB_DIR = path.dirname(__filename);

export function repoRoot() {
  return path.resolve(SCRIPTS_LIB_DIR, '..', '..');
}

export function packagesDir() {
  return path.join(repoRoot(), 'packages');
}

export function luxvimPackageDir() {
  return path.join(packagesDir(), 'luxvim');
}

export function runtimePackageDir(triple) {
  return path.join(packagesDir(), `runtime-${triple}`);
}

export function vendorPluginsDir() {
  return path.join(luxvimPackageDir(), 'vendor', 'plugins');
}

export function platformTriple(platform, arch) {
  return `${platform}-${arch}`;
}

export function nativePlatformTriple() {
  return platformTriple(process.platform, process.arch);
}
