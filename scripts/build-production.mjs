import { cp, mkdir, readFile, rm, writeFile, readdir } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { dirname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(fileURLToPath(new URL('..', import.meta.url)));
const out = join(root, 'dist');
const platformOut = join(root, 'dist-platform');
const release = '6.9.0';

async function copyFileOrDir(src, dest) {
  await mkdir(dirname(dest), { recursive:true });
  await cp(src, dest, { recursive:true, force:true });
}

async function walk(dir) {
  const rows = [];
  for (const entry of await readdir(dir, { withFileTypes:true })) {
    const full = join(dir, entry.name);
    if (entry.isDirectory()) rows.push(...await walk(full));
    else if (entry.isFile()) rows.push(full);
  }
  return rows;
}

async function integrityManifest(dir) {
  const files = (await walk(dir)).filter((file) => !file.endsWith('integrity.json')).sort();
  const result = {};
  for (const file of files) {
    const body = await readFile(file);
    result[relative(dir,file).replaceAll('\\','/')] = {
      bytes:body.length,
      sha256:createHash('sha256').update(body).digest('hex')
    };
  }
  return result;
}

await rm(out, { recursive:true, force:true });
await rm(platformOut, { recursive:true, force:true });
await mkdir(out, { recursive:true });
await mkdir(platformOut, { recursive:true });

for (const name of ['index.html','platform.html','favicon.svg','app.webmanifest','server.mjs','assets']) {
  await copyFileOrDir(join(root,name), join(out,name));
}
await writeFile(join(out,'package.json'), `${JSON.stringify({
  name:'optimum-production', version:release, private:true, type:'module',
  scripts:{ start:'node server.mjs' }, engines:{ node:'>=20.9' }
}, null, 2)}\n`);
await writeFile(join(out,'release.json'), `${JSON.stringify({ release, runtime:'node-static-supabase', built_at:new Date().toISOString() }, null, 2)}\n`);
await writeFile(join(out,'integrity.json'), `${JSON.stringify(await integrityManifest(out), null, 2)}\n`);

for (const name of ['index.html','favicon.svg','server.mjs','assets']) {
  await copyFileOrDir(join(root,'platform-console',name), join(platformOut,name));
}
await writeFile(join(platformOut,'package.json'), `${JSON.stringify({
  name:'optimum-platform-console-production', version:release, private:true, type:'module',
  scripts:{ start:'node server.mjs' }, engines:{ node:'>=20.9' }
}, null, 2)}\n`);
await writeFile(join(platformOut,'release.json'), `${JSON.stringify({ release, runtime:'node-static-supabase', built_at:new Date().toISOString() }, null, 2)}\n`);
await writeFile(join(platformOut,'integrity.json'), `${JSON.stringify(await integrityManifest(platformOut), null, 2)}\n`);

console.log(`Optimum ${release} production bundles built:`);
console.log(`- ${out}`);
console.log(`- ${platformOut}`);
console.log('No runtime npm dependencies are required.');
