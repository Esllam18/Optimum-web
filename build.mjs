import { cp, copyFile, mkdir, rm, writeFile, readdir, readFile, stat } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { join } from 'node:path';
import { prepareClientCssDelivery } from './scripts/performance-r2-css-delivery.mjs';

const RELEASE = '6.9.0';
const BASELINE = '6.9.1-production-certification-r1';

const rootUrl = new URL('./', import.meta.url);
const publicDir = new URL('./public/', import.meta.url);
const publicPath = fileURLToPath(publicDir);
const publicAssets = new URL('./public/assets/', import.meta.url);
const publicAssetsPath = fileURLToPath(publicAssets);

await mkdir(publicDir, { recursive: true });

if (existsSync(publicAssets)) {
  await rm(publicAssets, { recursive: true, force: true });
}

await cp(
  new URL('./assets/', import.meta.url),
  publicAssets,
  { recursive: true }
);

const sourceFiles = [
  'index.html',
  'platform.html',
  'app.webmanifest',
  'favicon.svg'
];

for (const file of sourceFiles) {
  const src = new URL(`./${file}`, rootUrl);
  if (existsSync(src)) {
    await copyFile(src, new URL(`./public/${file}`, rootUrl));
  }
}

await prepareClientCssDelivery({
  rootPath:fileURLToPath(rootUrl),
  outputPath:publicPath
});

const health = {
  ok: true,
  service: 'optimum',
  release: RELEASE,
  baseline: BASELINE,
  commit: process.env.VERCEL_GIT_COMMIT_SHA || process.env.GITHUB_SHA || null
};

await writeFile(
  join(publicPath, 'health.json'),
  `${JSON.stringify(health, null, 2)}\n`,
  'utf8'
);

async function listFiles(dir, prefix = '') {
  const entries = await readdir(dir, { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    const absolute = join(dir, entry.name);
    const relative = prefix ? `${prefix}/${entry.name}` : entry.name;
    if (entry.isDirectory()) {
      files.push(...await listFiles(absolute, relative));
    } else if (entry.isFile()) {
      files.push(relative.replace(/\\/g, '/'));
    }
  }
  return files;
}

const artifactFiles = [
  ...sourceFiles.filter((file) => existsSync(join(publicPath, file))),
  'health.json',
  ...(await listFiles(publicAssetsPath, 'assets'))
].sort((a, b) => a.localeCompare(b));

const integrity = {};
for (const relative of artifactFiles) {
  const absolute = join(publicPath, ...relative.split('/'));
  const body = await readFile(absolute);
  const info = await stat(absolute);
  integrity[relative] = {
    bytes: info.size,
    sha256: createHash('sha256').update(body).digest('hex')
  };
}

await writeFile(
  join(publicPath, 'integrity.json'),
  `${JSON.stringify(integrity, null, 2)}\n`,
  'utf8'
);

console.log(`Optimum Vercel artifact ready in public/ (${artifactFiles.length} integrity entries).`);
