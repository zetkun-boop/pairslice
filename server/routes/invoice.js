import { Router } from 'express';
import { validateInitData } from '../lib/hmac.js';

const router = Router();

const PRODUCTS = {
  single: {
    title: 'One Split',
    description: 'Split one image in half — perfect for this moment',
    stars: 5,
  },
  unlimited: {
    title: 'Unlimited Splits',
    description: 'Unlimited image splits forever — no more paywalls, ever',
    stars: 50,
  },
};

/**
 * POST /create-invoice
 * Body: { initData: string, productType: 'single' | 'unlimited' }
 *
 * Validates the caller's Telegram identity, then creates a
 * Telegram Stars invoice link via the Bot API and returns it.
 */
router.post('/create-invoice', async (req, res) => {
  const { initData, productType } = req.body;

  // 1. Validate product type
  const product = PRODUCTS[productType];
  if (!product) {
    return res.status(400).json({ error: 'invalid productType' });
  }

  // 2. Validate Telegram initData (HMAC)
  let userId;
  try {
    const params = validateInitData(initData, process.env.BOT_TOKEN);
    const userJson = params.get('user');
    if (!userJson) throw new Error('no user field in initData');
    userId = JSON.parse(userJson).id;
    if (!userId) throw new Error('no id in user');
  } catch (e) {
    console.warn('[invoice] initData validation failed:', e.message);
    return res.status(403).json({ error: 'invalid initData' });
  }

  // 3. Build invoice payload (max 128 bytes, not shown to user)
  const payload = JSON.stringify({ type: productType, uid: userId });

  // 4. Call Telegram Bot API — createInvoiceLink
  // CRITICAL: currency must be 'XTR' and provider_token must be '' for Stars
  const apiBody = {
    title: product.title,
    description: product.description,
    payload,
    currency: 'XTR',           // ISO code for Telegram Stars
    provider_token: '',         // Empty string required for Stars (not omitted)
    prices: [{ label: product.title, amount: product.stars }],
  };

  try {
    const tgRes = await fetch(
      `https://api.telegram.org/bot${process.env.BOT_TOKEN}/createInvoiceLink`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(apiBody),
      }
    );

    const tgJson = await tgRes.json();

    if (!tgJson.ok) {
      console.error('[invoice] Telegram API error:', tgJson.description);
      return res.status(502).json({ error: 'Telegram API error: ' + tgJson.description });
    }

    // tgJson.result is the invoice URL (e.g. https://t.me/$...)
    res.json({ invoiceUrl: tgJson.result });
  } catch (e) {
    console.error('[invoice] fetch error:', e.message);
    res.status(500).json({ error: 'could not create invoice' });
  }
});

export default router;
