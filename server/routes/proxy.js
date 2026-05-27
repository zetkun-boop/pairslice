import { Router } from 'express';

const router = Router();

const MAX_BYTES   = 30 * 1024 * 1024; // 30 MB
const TIMEOUT_MS  = 15_000;

/**
 * GET /proxy?url=<encoded-image-url>
 *
 * Server-side image proxy — bypasses browser CORS restrictions.
 * Basic SSRF protection: blocks private-network hosts.
 */
router.get('/proxy', async (req, res) => {
  const { url } = req.query;
  if (!url) return res.status(400).json({ error: 'url param required' });

  // Validate URL
  let parsed;
  try {
    parsed = new URL(url);
  } catch {
    return res.status(400).json({ error: 'invalid URL' });
  }

  if (!['http:', 'https:'].includes(parsed.protocol)) {
    return res.status(400).json({ error: 'only http/https URLs allowed' });
  }

  // SSRF guard — block private/loopback hosts
  const h = parsed.hostname;
  if (
    /^(localhost|127\.|0\.0\.0\.0)/i.test(h) ||
    /^10\.\d/i.test(h) ||
    /^192\.168\./i.test(h) ||
    /^172\.(1[6-9]|2\d|3[01])\./i.test(h)
  ) {
    return res.status(400).json({ error: 'private network URLs not allowed' });
  }

  try {
    const resp = await fetch(url, {
      headers: { 'User-Agent': 'Mozilla/5.0 (compatible; PairSliceProxy/1.0)' },
      redirect: 'follow',
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });

    if (!resp.ok) {
      return res.status(502).json({ error: `Remote server returned ${resp.status}` });
    }

    const ct = resp.headers.get('content-type') || '';
    if (!ct.startsWith('image/')) {
      return res.status(415).json({ error: 'URL does not point to an image' });
    }

    // Reject oversized images early via content-length
    const cl = parseInt(resp.headers.get('content-length') || '0', 10);
    if (cl > MAX_BYTES) {
      return res.status(413).json({ error: 'Image too large (max 30 MB)' });
    }

    const buf = await resp.arrayBuffer();
    if (buf.byteLength > MAX_BYTES) {
      return res.status(413).json({ error: 'Image too large (max 30 MB)' });
    }

    res.setHeader('Content-Type', ct);
    res.setHeader('Cache-Control', 'public, max-age=300');
    res.send(Buffer.from(buf));
  } catch (e) {
    console.error('[proxy] fetch error:', e.message);
    if (e.name === 'TimeoutError' || e.name === 'AbortError') {
      return res.status(504).json({ error: 'Request timed out' });
    }
    res.status(502).json({ error: 'Could not fetch the image' });
  }
});

export default router;
