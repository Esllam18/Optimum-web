import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const app=readFileSync(new URL('../assets/app.js',import.meta.url),'utf8');
const publicApp=readFileSync(new URL('../public/assets/app.js',import.meta.url),'utf8');
const css=readFileSync(new URL('../assets/styles.css',import.meta.url),'utf8');
const publicCss=readFileSync(new URL('../public/assets/styles.css',import.meta.url),'utf8');
const globals=readFileSync(new URL('../app/globals.css',import.meta.url),'utf8');
const platformCss=readFileSync(new URL('../platform-console/assets/styles.css',import.meta.url),'utf8');

for(const marker of [
  'PROJECT PORTFOLIO','pdc-portfolio-strip','project-open-primary',
  'PROJECT 360 · DELIVERY','project-health-chip','project-pulse-grid','project-context-strip','project-site-list',
  'SITE DELIVERY 360','site-context-hero','site-pulse-grid','site-context-grid','site-claim-card-calm',
  'CABINET 360','cabinet-context-hero','cabinet-pulse-grid','cabinet-folder-grid-primary',
  'entity-editor-form','entity-form-section','entity-form-advanced','entity-form-footer',
  'data-form="project"','data-form="site"','data-form="site-cabinet"','blueprint-picker'
]) assert.ok(app.includes(marker),`premium project context missing ${marker}`);

assert.ok(!app.includes('Every project in one actionable view'),'legacy project marketing hero copy should stay removed');
assert.ok(app.includes('data-action="site-open-work"'),'Site 360 must open task context at site scope');
assert.ok(app.includes('data-action="cabinet-open-work"'),'Cabinet 360 must open task context at cabinet scope');
assert.match(app,/site-open-work[\s\S]{0,500}focusContext/,'Site task action must preserve Project + Site context');
assert.match(app,/cabinet-open-work[\s\S]{0,500}focusContext/,'Cabinet task action must preserve Project + Site + Cabinet context');

for(const marker of [
  '.pdc-portfolio-strip','.project-health-chip','.project-pulse-grid','.project-context-strip',
  '.site-context-hero','.site-pulse-grid','.site-context-grid','.site-claim-card-calm',
  '.cabinet-context-hero','.cabinet-folder-grid-primary','.entity-form-section','.entity-form-advanced',
  '@media(max-width:680px)'
]) assert.ok(css.includes(marker),`premium project context CSS missing ${marker}`);

assert.equal(app,publicApp,'client app runtime mirror drift');
assert.equal(css,publicCss,'public CSS mirror drift');
assert.equal(css,globals,'Next globals CSS mirror drift');
assert.equal(css,platformCss,'platform CSS mirror drift');

console.log('PASS premium project context 6.9.1: calm portfolio, contextual 360s, form IA, responsive guards, and runtime mirrors verified');
