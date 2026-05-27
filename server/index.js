// ─────────────────────────────────────────────────────────────
//  PairSlice TMA — Backend entry point
//  Node.js 18+ required (native fetch, ESM)
// ─────────────────────────────────────────────────────────────

import 'dotenv/config'; // no-op on Railway (uses real env vars)
import express from 'express';
import { createBot } from './bot.js';
import { createWebhookRouter } from './routes/webhook.js';
import invoiceRouter from './routes/invoice.js';
import statusRouter from './routes/status.js';

// ── Env validation ──────────────────────────────────────────
const { BOT_TOKEN, FRONTEND_URL, PORT = '8080' } = process.env;

if (!BOT_TOKEN)    throw new Error('BOT_TOKEN env var is required');
if (!FRONTEND_URL) throw new Error('FRONTEND_URL env var is required');

// ── Express setup ───────────────────────────────────────────
const app = express();
app.use(express.json());

// CORS — open to all origins (Mini App runs in Telegram WebView,
// origin header may be null or vary; tightening can be done post-MVP)
app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  if (req.method === 'OPTIONS') return res.sendStatus(204);
  next();
});

// Health check (Railway uses this)
app.get('/', (_req, res) => res.json({ status: 'ok', app: 'pairslice-tma' }));

// ── Admin: test notification ─────────────────────────────────
// GET /admin/test-notify?secret=<last-8-chars-of-BOT_TOKEN>
// Sends a test Telegram message to OWNER_CHAT_ID.
app.get('/admin/test-notify', async (req, res) => {
  const ownerChatId = process.env.OWNER_CHAT_ID;

  if (!ownerChatId) {
    return res.status(500).json({
      error: 'OWNER_CHAT_ID not set',
      fix: 'Send /myid to @PairSliceBot → add the number to Railway Variables as OWNER_CHAT_ID',
    });
  }

  // Auth: last 8 characters of BOT_TOKEN (fast, no extra secrets needed)
  const expectedSecret = BOT_TOKEN.slice(-8);
  if (req.query.secret !== expectedSecret) {
    return res.status(403).json({ error: 'unauthorized — pass ?secret=<last-8-of-BOT_TOKEN>' });
  }

  try {
    const r = await fetch(`https://api.telegram.org/bot${BOT_TOKEN}/sendMessage`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        chat_id: ownerChatId,
        text: '🧪 *PairSlice — тест уведомлений*\n\nЕсли видишь это сообщение, нотификации донатов работают! ✅',
        parse_mode: 'Markdown',
      }),
    });
    const data = await r.json();
    if (data.ok) {
      res.json({ success: true, message: 'Notification sent — check your Telegram' });
    } else {
      res.status(502).json({ success: false, telegram_error: data.description });
    }
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ── Routes ──────────────────────────────────────────────────
app.use(invoiceRouter);    // POST /create-invoice
app.use(statusRouter);     // GET  /user/status

// ── Bot + Webhook ───────────────────────────────────────────
const bot = createBot(BOT_TOKEN, FRONTEND_URL);
app.use(createWebhookRouter(bot));  // POST /webhook

// ── Start ───────────────────────────────────────────────────
app.listen(parseInt(PORT), '0.0.0.0', async () => {
  console.log(`✅ PairSlice server running on port ${PORT}`);

  // Register webhook with Telegram automatically on startup.
  // Railway provides RAILWAY_PUBLIC_DOMAIN (e.g. "something.up.railway.app").
  // For custom domains set WEBHOOK_DOMAIN manually.
  const domain =
    process.env.RAILWAY_PUBLIC_DOMAIN ||
    process.env.WEBHOOK_DOMAIN;

  if (domain) {
    const webhookUrl = `https://${domain}/webhook`;
    try {
      await bot.api.setWebhook(webhookUrl, {
        // Drop pending updates from before this deploy to avoid re-processing
        drop_pending_updates: true,
      });
      console.log(`🔗 Telegram webhook registered: ${webhookUrl}`);
    } catch (e) {
      console.error('❌ Failed to register webhook:', e.message);
    }
  } else {
    console.warn(
      '⚠️  No domain env var found (RAILWAY_PUBLIC_DOMAIN or WEBHOOK_DOMAIN).\n' +
      '   Webhook NOT registered. Set one of these vars and redeploy,\n' +
      '   or call setWebhook manually: https://api.telegram.org/bot<TOKEN>/setWebhook?url=<URL>/webhook'
    );
  }
});
