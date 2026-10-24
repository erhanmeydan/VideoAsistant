import { readFile } from 'node:fs/promises';
import { createServer } from 'node:http';
import { join, normalize, extname } from 'node:path';

const CLIENT_ROOT = join('miniapp', 'client');

const CONTENT_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.webp': 'image/webp',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon'
};

export async function start(context) {
  const clientRoot = join(context.pluginRoot, CLIENT_ROOT);
  const clientEntry = await readFile(join(clientRoot, 'index.html'));

  const server = createServer((request, response) => {
    const url = new URL(request.url ?? '/', 'http://miniapp.local');

    if (request.method !== 'GET' && request.method !== 'HEAD') {
      response.writeHead(405, { 'content-type': 'application/json; charset=utf-8' });
      response.end(JSON.stringify({ error: 'method_not_allowed' }));
      return;
    }

    // Sayfa girişi
    if (url.pathname === '/dashboard' || url.pathname === '/') {
      response.writeHead(200, { 'content-type': 'text/html; charset=utf-8' });
      response.end(clientEntry);
      return;
    }

    // Statik varlıklar (yalnızca client dizini içinden)
    if (url.pathname.startsWith('/assets/')) {
      const relative = normalize(url.pathname.slice('/assets/'.length)).replace(/^(\.\.[/\\])+/, '');
      const filePath = join(clientRoot, 'assets', relative);
      if (!filePath.startsWith(join(clientRoot, 'assets'))) {
        response.writeHead(403, { 'content-type': 'application/json; charset=utf-8' });
        response.end(JSON.stringify({ error: 'forbidden' }));
        return;
      }
      readFile(filePath)
        .then((data) => {
          response.writeHead(200, {
            'content-type': CONTENT_TYPES[extname(filePath).toLowerCase()] ?? 'application/octet-stream',
            'content-length': data.length,
            'cache-control': 'no-cache'
          });
          response.end(data);
        })
        .catch(() => {
          response.writeHead(404, { 'content-type': 'application/json; charset=utf-8' });
          response.end(JSON.stringify({ error: 'not_found' }));
        });
      return;
    }

    response.writeHead(404, { 'content-type': 'application/json; charset=utf-8' });
    response.end(JSON.stringify({ error: 'not_found' }));
  });

  await new Promise((resolve, reject) => {
    const onError = (error) => reject(error);
    server.once('error', onError);
    server.listen(context.listen.port, context.listen.host, () => {
      server.off('error', onError);
      resolve();
    });
  });

  let disposal;
  const dispose = () => {
    if (disposal) return disposal;
    context.signal.removeEventListener('abort', onAbort);
    disposal = new Promise((resolve, reject) => {
      server.close((error) => (error ? reject(error) : resolve()));
    });
    return disposal;
  };
  const onAbort = () => {
    void dispose().catch(() => undefined);
  };
  context.signal.addEventListener('abort', onAbort, { once: true });
  if (context.signal.aborted) await dispose();

  return { dispose };
}
