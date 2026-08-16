import { createHash } from 'node:crypto';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { join } from 'node:path';

export const CSS_DELIVERY_VERSION = 'r2';
export const CSS_FILES = Object.freeze({
  core: 'styles-core.css',
  engineering: 'styles-engineering.css',
  work: 'styles-work.css',
  management: 'styles-management.css',
  field: 'styles-field.css',
  platform: 'styles-platform.css',
  manifest: 'styles-r2-manifest.json'
});

const CLIENT_GROUPS = ['engineering','work','management','field'];
const ALL_GROUPS = ['core',...CLIENT_GROUPS,'platform'];
const RECURSIVE_AT_RULES = new Set(['media','supports','container','document','scope','starting-style']);
const PREFIX_FALLBACKS = [
  [/^(engineering|eng-|cad-)/i,'engineering'],
  [/^platform-/i,'platform']
];

const sha256 = (value) => createHash('sha256').update(value).digest('hex');
const utf8Bytes = (value) => Buffer.byteLength(value,'utf8');

function skipString(text, i) {
  const quote = text[i++];
  while (i < text.length) {
    if (text[i] === '\\') { i += 2; continue; }
    if (text[i] === quote) return i + 1;
    i++;
  }
  return i;
}

function skipComment(text, i) {
  const end = text.indexOf('*/', i + 2);
  return end === -1 ? text.length : end + 2;
}

function findHeaderBoundary(text, start) {
  let paren=0, bracket=0;
  for (let i=start;i<text.length;i++) {
    const ch=text[i];
    if (ch==='/' && text[i+1]==='*') { i=skipComment(text,i)-1; continue; }
    if (ch==='"' || ch==="'") { i=skipString(text,i)-1; continue; }
    if (ch==='(') paren++;
    else if (ch===')') paren=Math.max(0,paren-1);
    else if (ch==='[') bracket++;
    else if (ch===']') bracket=Math.max(0,bracket-1);
    else if (paren===0 && bracket===0 && (ch==='{' || ch===';')) return {index:i,char:ch};
  }
  return null;
}

function findMatchingBrace(text, openIndex) {
  let depth=1;
  for (let i=openIndex+1;i<text.length;i++) {
    const ch=text[i];
    if (ch==='/' && text[i+1]==='*') { i=skipComment(text,i)-1; continue; }
    if (ch==='"' || ch==="'") { i=skipString(text,i)-1; continue; }
    if (ch==='{') depth++;
    else if (ch==='}' && --depth===0) return i;
  }
  throw new Error(`Unbalanced CSS block starting at byte ${openIndex}`);
}

export function parseTopLevelCss(text) {
  const nodes=[];
  let i=0;
  while (i<text.length) {
    if (/\s/.test(text[i])) {
      const start=i;
      while (i<text.length && /\s/.test(text[i])) i++;
      nodes.push({type:'space',raw:text.slice(start,i)});
      continue;
    }
    if (text[i]==='/' && text[i+1]==='*') {
      const start=i;
      i=skipComment(text,i);
      nodes.push({type:'comment',raw:text.slice(start,i)});
      continue;
    }
    const start=i;
    const boundary=findHeaderBoundary(text,start);
    if (!boundary) {
      const raw=text.slice(start);
      if (raw.trim()) nodes.push({type:'raw',raw});
      break;
    }
    if (boundary.char===';') {
      const raw=text.slice(start,boundary.index+1);
      nodes.push({type:'statement',raw,header:text.slice(start,boundary.index).trim()});
      i=boundary.index+1;
      continue;
    }
    const close=findMatchingBrace(text,boundary.index);
    const raw=text.slice(start,close+1);
    const header=text.slice(start,boundary.index).trim();
    const inner=text.slice(boundary.index+1,close);
    nodes.push({
      type:header.startsWith('@')?'at-block':'style',
      raw,header,inner,
      openIndex:boundary.index-start
    });
    i=close+1;
  }
  return nodes;
}

function splitSelectorList(header) {
  const out=[];
  let start=0,paren=0,bracket=0;
  for(let i=0;i<header.length;i++){
    const ch=header[i];
    if(ch==='/'&&header[i+1]==='*'){i=skipComment(header,i)-1;continue;}
    if(ch==='"'||ch==="'"){i=skipString(header,i)-1;continue;}
    if(ch==='(')paren++;
    else if(ch===')')paren=Math.max(0,paren-1);
    else if(ch==='[')bracket++;
    else if(ch===']')bracket=Math.max(0,bracket-1);
    else if(ch===','&&paren===0&&bracket===0){
      out.push(header.slice(start,i).trim());start=i+1;
    }
  }
  out.push(header.slice(start).trim());
  return out.filter(Boolean);
}

function selectorTokens(selector){
  const tokens=new Set();
  for(const match of selector.matchAll(/\.(-?[_a-zA-Z][\w-]*)/g)) tokens.add(match[1]);
  for(const match of selector.matchAll(/#(-?[_a-zA-Z][\w-]*)/g)) tokens.add(match[1]);
  for(const match of selector.matchAll(/\[\s*(data-[\w-]+)/gi)) tokens.add(match[1]);
  return [...tokens];
}

function combineSources(list){return (list||[]).join('\n');}

function createOwnership(sourceTexts){
  const haystacks={};
  for(const group of ALL_GROUPS) haystacks[group]=combineSources(sourceTexts[group]);
  const cache=new Map();
  return (token)=>{
    if(cache.has(token))return cache.get(token);
    if(haystacks.core.includes(token)){cache.set(token,'core');return 'core';}
    const routeHits=CLIENT_GROUPS.filter(group=>haystacks[group].includes(token));
    if(routeHits.length===1){cache.set(token,routeHits[0]);return routeHits[0];}
    if(routeHits.length>1){cache.set(token,'shared');return 'shared';}
    if(haystacks.platform.includes(token)){cache.set(token,'platform');return 'platform';}
    for(const [pattern,group] of PREFIX_FALLBACKS){
      if(pattern.test(token)){cache.set(token,group);return group;}
    }
    cache.set(token,'unknown');return 'unknown';
  };
}

function selectorOwner(selector, tokenOwner){
  const anchors=new Set();
  for(const token of selectorTokens(selector)){
    const owner=tokenOwner(token);
    if(CLIENT_GROUPS.includes(owner)||owner==='platform')anchors.add(owner);
  }
  return anchors.size===1?[...anchors][0]:'core';
}

function emptyOutputs(){return Object.fromEntries(ALL_GROUPS.map(group=>[group,[]]));}
function emptyStats(){return {styleRules:0,selectors:0,atomicAtRules:0,containers:0,emittedSelectors:0};}
function append(target,source){for(const group of ALL_GROUPS)target[group].push(...source[group]);}

function atRuleName(header){
  const match=header.match(/^@([\w-]+)/);
  return match?.[1]?.toLowerCase()||'';
}

function splitCssInternal(text,tokenOwner,stats){
  const out=emptyOutputs();
  for(const node of parseTopLevelCss(text)){
    if(node.type==='space'||node.type==='comment')continue;
    if(node.type==='raw'||node.type==='statement'){
      out.core.push(node.raw.trim());
      if(node.type==='statement')stats.atomicAtRules++;
      continue;
    }
    if(node.type==='style'){
      stats.styleRules++;
      const selectors=splitSelectorList(node.header);
      stats.selectors+=selectors.length;
      const buckets=new Map();
      for(const selector of selectors){
        const owner=selectorOwner(selector,tokenOwner);
        if(!buckets.has(owner))buckets.set(owner,[]);
        buckets.get(owner).push(selector);
      }
      for(const [owner,ownedSelectors] of buckets){
        const normalized=ALL_GROUPS.includes(owner)?owner:'core';
        out[normalized].push(`${ownedSelectors.join(',')}{${node.inner}}`);
        stats.emittedSelectors+=ownedSelectors.length;
      }
      continue;
    }
    const name=atRuleName(node.header);
    if(RECURSIVE_AT_RULES.has(name)){
      stats.containers++;
      const nested=splitCssInternal(node.inner,tokenOwner,stats);
      for(const group of ALL_GROUPS){
        const body=nested[group].filter(Boolean).join('\n');
        if(body.trim())out[group].push(`${node.header}{\n${body}\n}`);
      }
    }else{
      out.core.push(node.raw.trim());
      stats.atomicAtRules++;
    }
  }
  return out;
}

export function splitCssForDelivery(css,sourceTexts){
  const tokenOwner=createOwnership(sourceTexts);
  const stats=emptyStats();
  const pieces=splitCssInternal(css,tokenOwner,stats);
  if(stats.selectors!==stats.emittedSelectors){
    throw new Error(`CSS selector coverage mismatch: source=${stats.selectors}, emitted=${stats.emittedSelectors}`);
  }
  const outputs={};
  for(const group of ALL_GROUPS){
    outputs[group]=`${pieces[group].filter(Boolean).join('\n')}\n`;
  }
  return {outputs,stats};
}

async function readText(path){return readFile(path,'utf8');}

export async function collectCssOwnershipSources(rootPath){
  const load=async(relative)=>readText(join(rootPath,...relative.split('/')));
  return {
    core:await Promise.all([
      'assets/app.js','assets/access-engine.js','assets/organization-os.js','index.html'
    ].map(load)),
    engineering:[await load('assets/engineering.js')],
    work:[await load('assets/work-os.js')],
    management:await Promise.all(['assets/operations-center.js','assets/project-control.js'].map(load)),
    field:[await load('assets/site-supervisor.js')],
    platform:await Promise.all(['assets/platform.js','platform.html'].map(load))
  };
}

function transformClientIndex(indexHtml){
  let out=indexHtml;
  const htmlCount=(out.match(/<html\b/g)||[]).length;
  if(htmlCount!==1)throw new Error(`Expected exactly one <html> tag, found ${htmlCount}`);
  if(!/\bdata-app=["']client["']/.test(out))throw new Error('Client index is missing data-app="client"');
  out=out.replace(/<html\b([^>]*\bdata-app=["']client["'][^>]*)>/,
    (full,attrs)=>/\bdata-css-delivery=/.test(attrs)?full:`<html${attrs} data-css-delivery="${CSS_DELIVERY_VERSION}">`);
  const linkPattern=/<link\b[^>]*rel=["']stylesheet["'][^>]*href=["']\.\/assets\/styles\.css\?v=6\.9\.0["'][^>]*\/?>/g;
  const matches=[...out.matchAll(linkPattern)];
  if(matches.length!==1)throw new Error(`Expected one canonical client stylesheet link, found ${matches.length}`);
  out=out.replace(
    linkPattern,
    `<link rel="stylesheet" data-optimum-core-style href="./assets/${CSS_FILES.core}?v=6.9.0" />\n  <link rel="preload" data-optimum-full-css-preload href="./assets/styles.css?v=6.9.0" as="style" />`
  );
  return out;
}

export async function prepareClientCssDelivery({rootPath,outputPath}){
  const canonicalPath=join(rootPath,'assets','styles.css');
  const cssRaw=await readText(canonicalPath);
  const css=cssRaw.replace(/\r\n?/g,'\n');
  const sources=await collectCssOwnershipSources(rootPath);
  const {outputs,stats}=splitCssForDelivery(css,sources);
  const assetsOut=join(outputPath,'assets');
  await mkdir(assetsOut,{recursive:true});

  const fileByGroup={
    core:CSS_FILES.core,
    engineering:CSS_FILES.engineering,
    work:CSS_FILES.work,
    management:CSS_FILES.management,
    field:CSS_FILES.field,
    platform:CSS_FILES.platform
  };
  const chunkMetrics={};
  for(const [group,file] of Object.entries(fileByGroup)){
    const body=outputs[group];
    await writeFile(join(assetsOut,file),body,'utf8');
    chunkMetrics[group]={file,bytes:utf8Bytes(body),sha256:sha256(body)};
  }

  const canonicalBytes=utf8Bytes(css);
  const deferredClientBytes=CLIENT_GROUPS.reduce((sum,group)=>sum+chunkMetrics[group].bytes,0);
  const coreBytes=chunkMetrics.core.bytes;
  const manifest={
    version:CSS_DELIVERY_VERSION,
    canonical:{file:'styles.css',normalizedBytes:canonicalBytes,normalizedSha256:sha256(css)},
    chunks:chunkMetrics,
    client:{
      coreBytes,
      coreKiB:Number((coreBytes/1024).toFixed(1)),
      deferredRouteBytes:deferredClientBytes,
      deferredRouteKiB:Number((deferredClientBytes/1024).toFixed(1)),
      initialReductionPercent:Number(((1-coreBytes/canonicalBytes)*100).toFixed(1))
    },
    coverage:stats
  };
  await writeFile(join(assetsOut,CSS_FILES.manifest),`${JSON.stringify(manifest,null,2)}\n`,'utf8');

  const indexPath=join(outputPath,'index.html');
  const indexHtml=await readText(indexPath);
  await writeFile(indexPath,transformClientIndex(indexHtml),'utf8');

  return manifest;
}
