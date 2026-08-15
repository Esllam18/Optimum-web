import fs from 'node:fs';
const app=fs.readFileSync(new URL('../assets/app.js',import.meta.url),'utf8');
const css=fs.readFileSync(new URL('../assets/styles.css',import.meta.url),'utf8');
const checks=[
  ['navigation scroll container', app.includes('sidebar-nav-scroll')],
  ['mobile navigation scrim', app.includes('sidebar-scrim') && css.includes('.sidebar-scrim')],
  ['grouped topbar primary actions', app.includes('topbar-primary-actions')],
  ['grouped topbar utility actions', app.includes('topbar-utility-actions')],
  ['duplicate foundation badge removed from shell', !app.includes('<div class="foundation-badge"><strong>')],
  ['duplicate sidebar sign-out removed', !/sidebar-bottom[\s\S]{0,500}data-action="sign-out"/.test(app)],
  ['active navigation semantics', app.includes('aria-current="page"')],
  ['responsive mobile breakpoint', css.includes('@media(max-width:900px)') && css.includes('width:min(290px,86vw)')],
  ['calm content width token', css.includes('--content-max:1480px')],
  ['reduced mobile utility noise', css.includes('.topbar-secondary-action{display:none;}')],
];
let failed=0;
for(const [name,ok] of checks){console.log(`${ok?'PASS':'FAIL'}  ${name}`);if(!ok)failed++;}
if(failed)process.exit(1);
console.log(`Feature 0 static gate: ${checks.length}/${checks.length} PASS`);
