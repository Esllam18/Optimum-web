import fs from 'node:fs';
import path from 'node:path';
const root=path.resolve(new URL('..',import.meta.url).pathname);
const css=fs.readFileSync(path.join(root,'assets/styles.css'),'utf8');
const app=fs.readFileSync(path.join(root,'assets/app.js'),'utf8');
const index=fs.readFileSync(path.join(root,'index.html'),'utf8');
const server=fs.readFileSync(path.join(root,'server.mjs'),'utf8');
const checks=[
 ['IBM Plex Arabic token',css.includes('--font-ar:"IBM Plex Sans Arabic"')],
 ['Inter English token',css.includes('--font-en:"Inter"')],
 ['non-blocking premium font loader',app.includes('loadPremiumFonts')&&app.includes('fonts.googleapis.com/css2?family=IBM+Plex+Sans+Arabic')],
 ['font CSP allowlist',server.includes('https://fonts.googleapis.com')&&server.includes('https://fonts.gstatic.com')],
 ['sidebar persistence key',app.includes("optimum.shell.sidebarCollapsed.v2")],
 ['sidebar collapse control',app.includes('data-action="sidebar-collapse"')&&css.includes('.app-shell.sidebar-collapsed')],
 ['utility menu consolidation',app.includes('data-action="utility-menu"')&&app.includes('utility-menu-pop')],
 ['navigation groups',app.includes("L('مساحة العمل','Workspace')")&&app.includes("L('التسليم والمعلومات','Delivery & information')")&&app.includes("L('الإدارة','Administration')")],
 ['personal density mode',app.includes('data-action="toggle-density"')&&css.includes('html[data-density="compact"]')],
 ['premium drawer markup',app.includes('premium-drawer-wrap')&&app.includes('drawer-handle')&&app.includes('drawer-eyebrow')],
 ['premium drawer motion',css.includes('optimumDrawerInLtr')&&css.includes('optimumSheetUp')],
 ['overlay closing motion',app.includes('dismissOverlay')&&css.includes('optimumDrawerOutLtr')&&css.includes('optimumSheetDown')],
 ['reduced motion safety',css.includes('@media(prefers-reduced-motion:reduce)')],
 ['card system v2',css.includes('--shadow-card:')&&css.includes('Cards: fewer visual walls')],
 ['responsive sheet treatment',css.includes('height:min(94dvh,calc(100dvh - 16px))')],
 ['external fonts do not block document parse',!index.includes('fonts.googleapis.com/css2?family=IBM+Plex+Sans+Arabic')],
];
let passed=0;
for(const [name,ok] of checks){console.log(`${ok?'PASS':'FAIL'}  ${name}`);if(ok)passed++;}
if(passed!==checks.length){console.error(`Foundation V2 static gate: ${passed}/${checks.length}`);process.exit(1)}
console.log(`Foundation V2 static gate: ${passed}/${checks.length} PASS`);
