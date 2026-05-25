import { Router } from 'express';

/**
 * Creates a webhook router bound to a Grammy bot instance.
 *
 * Telegram sends ALL updates (messages, pre_checkout_query,
 * successful_payment, etc.) to POST /webhook.
 * Grammy's handleUpdate() routes them to the handlers defined in bot.js.
 *
 * @param {import('grammy').Bot} bot
 */
export function createWebhookRouter(bot) {
  const router = Router();

  router.post('/webhook', async (req, res) => {
    try {
      await bot.handleUpdate(req.body);
    } catch (e) {
      // Never let uncaught errors stop the 200 response —
      // Telegram retries updates that don't get a 200 within 60s.
      console.error('[webhook] handleUpdate error:', e.message);
    }
    res.sendStatus(200);
  });

  return router;
}
