import http from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import { brotliCompress, gzip } from 'node:zlib';
import { promisify } from 'node:util';
import { extname, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(fileURLToPath(new URL('.', import.meta.url)));
const port = Number(process.env.PLATFORM_PORT || 4174);
const host = process.env.HOST || '0.0.0.0';
const clientAppUrl = process.env.OPTIMUM_CLIENT_APP_URL || 'http://localhost:4173/';
const release = '6.9.0';
const br = promisify(brotliCompress);
const gz = promisify(gzip);
const escapeHtmlAttr = (value) => String(value).replace(/[&<>"']/g, (ch) => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[ch]));
const mime = {
  '.html':'text/html; charset=utf-8', '.js':'text/javascript; charset=utf-8', '.css':'text/css; charset=utf-8',
  '.svg':'image/svg+xml', '.json':'application/json; charset=utf-8', '.png':'image/png', '.jpg':'image/jpeg',
  '.jpeg':'image/jpeg', '.webp':'image/webp', '.ico':'image/x-icon', '.woff2':'font/woff2'
};
const compressible = /^(text\/|application\/(javascript|json)|image\/svg\+xml)/;
const csp = "default-src 'self'; connect-src 'self' https://wzcaquxuvqfbstpxujsj.supabase.co; img-src 'self' data: blob: https://wzcaquxuvqfbstpxujsj.supabase.co; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; script-src 'self'; font-src 'self' https://fonts.gstatic.com data:; object-src 'none'; base-uri 'self'; form-action 'self'; frame-ancestors 'none'";

function securityHeaders() {
  return {
    'X-Content-Type-Options':'nosniff', 'X-Frame-Options':'DENY', 'Referrer-Policy':'strict-origin-when-cross-origin',
    'Permissions-Policy':'camera=(), microphone=(), geolocation=()', 'Cross-Origin-Opener-Policy':'same-origin',
    'Cross-Origin-Resource-Policy':'same-origin', 'X-Permitted-Cross-Domain-Policies':'none',
    'Strict-Transport-Security':'max-age=31536000; includeSubDomains', 'Content-Security-Policy':csp
  };
}
function resolvePath(pathname) {
  const decoded = decodeURIComponent(pathname);
  if (decoded.includes('\0')) throw Object.assign(new Error('Bad path'), { status:400 });
  const normalized = decoded === '/' || decoded === '/platform' || decoded === '/platform/' ? '/index.html' : decoded;
  const file = resolve(root, `.${normalized}`);
  if (file !== root && !file.startsWith(`${root}${sep}`)) throw Object.assign(new Error('Bad path'), { status:400 });
  return file;
}
async function encodedBody(req, body, contentType) {
  if (body.length < 1024 || !compressible.test(contentType)) return { body, encoding:null };
  const accepts = req.headers['accept-encoding'] || '';
  if (/\bbr\b/.test(accepts)) return { body:await br(body), encoding:'br' };
  if (/\bgzip\b/.test(accepts)) return { body:await gz(body), encoding:'gzip' };
  return { body, encoding:null };
}

const server = http.createServer(async (req,res)=>{
  const baseHeaders = securityHeaders();
  try {
    if (!['GET','HEAD'].includes(req.method || 'GET')) {
      res.writeHead(405, { ...baseHeaders, 'Allow':'GET, HEAD', 'Content-Type':'text/plain; charset=utf-8' });
      return res.end('Method not allowed');
    }
    const url = new URL(req.url || '/', `http://${req.headers.host || 'localhost'}`);
    if (url.pathname === '/health' || url.pathname === '/healthz') {
      const body = Buffer.from(JSON.stringify({ ok:true, service:'optimum-platform-console', release, uptime_seconds:Math.floor(process.uptime()) }));
      res.writeHead(200, { ...baseHeaders, 'Content-Type':'application/json; charset=utf-8', 'Cache-Control':'no-store', 'Content-Length':String(body.length) });
      return req.method === 'HEAD' ? res.end() : res.end(body);
    }
    const file = resolvePath(url.pathname);
    const info = await stat(file).catch(() => null);
    if (!info?.isFile()) {
      res.writeHead(404, { ...baseHeaders, 'Content-Type':'text/plain; charset=utf-8', 'Cache-Control':'no-store' });
      return res.end('Not found');
    }
    let raw = await readFile(file);
    if (file.endsWith('index.html')) raw = Buffer.from(raw.toString('utf8').replace('__OPTIMUM_CLIENT_APP_URL__', escapeHtmlAttr(clientAppUrl)));
    const etag = `W/\"${info.size.toString(16)}-${Math.floor(info.mtimeMs).toString(16)}\"`;
    const contentType = mime[extname(file).toLowerCase()] || 'application/octet-stream';
    const cache = file.endsWith('.html') ? { 'Cache-Control':'no-store, max-age=0', 'Pragma':'no-cache', 'Expires':'0' } : { 'Cache-Control':'public, max-age=300, must-revalidate' };
    const sharedHeaders = { ...baseHeaders, ...cache, 'Content-Type':contentType, 'ETag':etag, 'Vary':'Accept-Encoding' };
    if (req.headers['if-none-match'] === etag) { res.writeHead(304, sharedHeaders); return res.end(); }
    const encoded = await encodedBody(req, raw, contentType);
    res.writeHead(200, { ...sharedHeaders, 'Content-Length':String(encoded.body.length), ...(encoded.encoding ? { 'Content-Encoding':encoded.encoding } : {}) });
    return req.method === 'HEAD' ? res.end() : res.end(encoded.body);
  } catch (error) {
    const status = Number(error?.status) || 500;
    if (status >= 500) console.error('[optimum-platform-server]', error);
    res.writeHead(status, { ...baseHeaders, 'Content-Type':'text/plain; charset=utf-8', 'Cache-Control':'no-store' });
    res.end(status === 400 ? 'Bad request' : 'Server error');
  }
});
server.keepAliveTimeout = 65_000;
server.headersTimeout = 70_000;
server.requestTimeout = 30_000;
server.listen(port,host,()=>console.log(`Optimum Platform Console ${release} is running on http://${host}:${port}`));
function shutdown(signal) { console.log(`Optimum Platform Console received ${signal}; closing.`); server.close(()=>process.exit(0)); setTimeout(()=>process.exit(1),10_000).unref(); }
process.on('SIGTERM',()=>shutdown('SIGTERM'));
process.on('SIGINT',()=>shutdown('SIGINT'));
