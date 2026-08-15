import { cp, copyFile, mkdir, rm } from 'node:fs/promises';
import { existsSync } from 'node:fs';

const publicDir = new URL('./public/', import.meta.url);
await mkdir(publicDir, { recursive: true });

const publicAssets = new URL('./public/assets/', import.meta.url);
if (existsSync(publicAssets)) {
  await rm(publicAssets, { recursive: true, force: true });
}

await cp(
  new URL('./assets/', import.meta.url),
  publicAssets,
  { recursive: true }
);

const files = [
  'index.html',
  'platform.html',
  'app.webmanifest',
  'favicon.svg',
  'integrity.json'
];

for (const file of files) {
  const src = new URL(`./${file}`, import.meta.url);
  if (existsSync(src)) {
    await copyFile(src, new URL(`./public/${file}`, import.meta.url));
  }
}

console.log('Optimum artifact ready in public/');
