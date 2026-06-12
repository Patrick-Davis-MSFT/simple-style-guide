// ---------------------------------------------------------------------------
// server.js — Lightweight Node.js server for the Web App
//
// Serves the Vite-built SPA and reverse-proxies /api/* requests to the
// private Function App over the VNet.  Zero external dependencies — uses
// only built-in Node.js modules.
// ---------------------------------------------------------------------------
import fs from 'node:fs';
import http from 'node:http';
import https from 'node:https';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const DIST_DIR = path.join(SCRIPT_DIR, 'dist');

const PORT               = process.env.PORT || 8080;
const FUNCTION_APP_URL   = (process.env.FUNCTION_APP_INTERNAL_URL || '').replace(/\/$/, '');
const STYLE_CHECK_API_URL = (process.env.STYLE_CHECK_API_URL || '').trim();
const STATIC_DIR         = fs.existsSync(DIST_DIR) ? DIST_DIR : SCRIPT_DIR;

// ── MIME types ────────────────────────────────────────────────────
const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js':   'text/javascript; charset=utf-8',
  '.css':  'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png':  'image/png',
  '.jpg':  'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif':  'image/gif',
  '.svg':  'image/svg+xml',
  '.ico':  'image/x-icon',
  '.woff': 'font/woff',
  '.woff2':'font/woff2',
  '.ttf':  'font/ttf',
  '.map':  'application/json',
  '.xml':  'application/xml',
  '.txt':  'text/plain; charset=utf-8',
};

// ── Static file server (SPA fallback) ─────────────────────────────
function serveStatic(req, res) {
  const urlPath  = new URL(req.url, `http://${req.headers.host}`).pathname;
  let filePath   = path.join(STATIC_DIR, decodeURIComponent(urlPath));

  // Prevent path traversal
  if (!filePath.startsWith(STATIC_DIR)) {
    res.writeHead(403);
    res.end('Forbidden');
    return;
  }

  if (filePath.endsWith('/') || filePath === STATIC_DIR) {
    filePath = path.join(filePath, 'index.html');
  }

  fs.stat(filePath, (err, stats) => {
    if (!err && stats.isFile()) {
      const ext = path.extname(filePath).toLowerCase();
      res.writeHead(200, { 'Content-Type': MIME[ext] || 'application/octet-stream' });
      fs.createReadStream(filePath).pipe(res);
    } else {
      // SPA fallback — serve index.html for client-side routing
      const indexPath = path.join(STATIC_DIR, 'index.html');
      fs.stat(indexPath, (indexErr, indexStats) => {
        if (!indexErr && indexStats.isFile()) {
          res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
          fs.createReadStream(indexPath).pipe(res);
          return;
        }

        res.writeHead(404, { 'Content-Type': 'application/json; charset=utf-8' });
        res.end(JSON.stringify({ error: 'Not Found', message: 'index.html is missing from app content.' }));
      });
    }
  });
}

// ── Reverse proxy /api/* → Function App ───────────────────────────
function proxyRequest(req, res) {
  if (!FUNCTION_APP_URL) {
    res.writeHead(503, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Service Unavailable', message: 'FUNCTION_APP_INTERNAL_URL not configured' }));
    return;
  }

  const targetUrl = new URL(req.url, FUNCTION_APP_URL);
  const isHttps   = targetUrl.protocol === 'https:';
  const transport = isHttps ? https : http;

  // Build outgoing headers
  const fwdHeaders = Object.assign({}, req.headers);
  fwdHeaders.host = targetUrl.hostname;

  const options = {
    hostname: targetUrl.hostname,
    port:     targetUrl.port || (isHttps ? 443 : 80),
    path:     targetUrl.pathname + (targetUrl.search || ''),
    method:   req.method,
    headers:  fwdHeaders,
    timeout:  120000,   // 2-minute timeout for AI completions
  };

  const proxyReq = transport.request(options, (proxyRes) => {
    res.writeHead(proxyRes.statusCode, proxyRes.headers);
    proxyRes.pipe(res);
  });

  proxyReq.on('error', (err) => {
    console.error(`[proxy] ${req.method} ${req.url} → ${FUNCTION_APP_URL} error: ${err.message}`);
    if (!res.headersSent) {
      res.writeHead(502, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'Bad Gateway', message: 'Failed to reach Function App' }));
    }
  });

  proxyReq.on('timeout', () => {
    console.error(`[proxy] ${req.method} ${req.url} → timeout`);
    proxyReq.destroy(new Error('Proxy request timed out'));
  });

  req.pipe(proxyReq);
}

// ── Runtime configuration endpoint ────────────────────────────────
function serveConfig(req, res) {
  const payload = JSON.stringify({
    functionUrl: STYLE_CHECK_API_URL || '/api/style-check',
  });
  res.writeHead(200, {
    'Content-Type':  'application/json; charset=utf-8',
    'Cache-Control': 'no-cache',
  });
  res.end(payload);
}

// ── HTTP server ───────────────────────────────────────────────────
const server = http.createServer((req, res) => {
  if (req.url === '/api/config' && req.method === 'GET') {
    serveConfig(req, res);
  } else if (req.url.startsWith('/api/') && FUNCTION_APP_URL) {
    proxyRequest(req, res);
  } else {
    serveStatic(req, res);
  }
});

server.listen(PORT, () => {
  console.log(`[server] Listening on port ${PORT}`);
  console.log(`[server] Static dir: ${STATIC_DIR}`);
  console.log(`[server] Function App URL: ${FUNCTION_APP_URL || '(not configured — proxy disabled)'}`);
  console.log(`[server] Style Check API URL: ${STYLE_CHECK_API_URL || '(default: /api/style-check)'}`);
});
