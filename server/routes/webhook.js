import { Router } from 'express';
import { webhookCallback } from 'grammy';

/**
 * Creates a webhook router bound to a Grammy bot instance.
 *
 * Telegram sends ALL updates (messages, pre_checkout_query,
 * successful_payment, etc.) to POST /webhook.
 * Grammy's webhookCallback handles timing correctly — especially important
 * for pre_checkout_query which must be answered within 10 seconds.
 *
 * @param {import('grammy').Bot} bot
 */
export function createWebhookRouter(bot) {
  const router = Router();

  router.post('/webhook', webhookCallback(bot, 'express'));

  return router;
}
