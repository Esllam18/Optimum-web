import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const pkgPath = path.join(root, 'package.json');
const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));

pkg.scripts ||= {};
pkg.scripts['test:certificationr1'] = 'node build.mjs && node tests/production-certification-r1.mjs';

const release = String(pkg.scripts['test:release'] || '');
if (!release) throw new Error('test:release script is missing');

if (!release.includes('test:certificationr1')) {
  if (release.includes('&& npm run test:production-runtime')) {
    pkg.scripts['test:release'] = release.replace(
      '&& npm run test:production-runtime',
      '&& npm run test:certificationr1 && npm run test:production-runtime'
    );
  } else {
    pkg.scripts['test:release'] = `${release} && npm run test:certificationr1`;
  }
}

fs.writeFileSync(pkgPath, `${JSON.stringify(pkg, null, 2)}\n`, 'utf8');
console.log('package.json certification scripts patched without changing the 6.9.0 version contract.');
