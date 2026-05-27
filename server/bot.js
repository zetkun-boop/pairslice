import { Bot, InlineKeyboard } from 'grammy';
import { grantSplit, grantPremium } from './lib/store.js';

/**
 * Creates and configures the Grammy bot.
 *
 * @param {string} token       — Telegram bot token from @BotFather
 * @param {string} frontendUrl — Vercel URL of the Mini App
 * @returns {Bot}
 */
export function createBot(token, frontendUrl) {
  const bot = new Bot(token);

  // ── /start ─────────────────────────────────────────────────
  bot.command('start', async (ctx) => {
    const kb = new InlineKeyboard().webApp('Open PairSlice ✂️', frontendUrl);
    await ctx.reply(
      '👋 Welcome to *PairSlice*!\n\n' +
      'Split any image in half for a seamless Threads carousel — free, no limits, ever.\n\n' +
      'If you enjoy it, you can support the developer with ⭐ Stars right inside the app!',
      { parse_mode: 'Markdown', reply_markup: kb }
    );
  });

  // ── /myid — returns the caller's Telegram chat ID ──────────
  bot.command('myid', async (ctx) => {
    await ctx.reply(`Your Telegram chat ID: \`${ctx.from.id}\``, { parse_mode: 'Markdown' });
  });

  // ── pre_checkout_query ─────────────────────────────────────
  // Must be answered within 10 seconds. Always approve — digital goods.
  bot.on('pre_checkout_query', async (ctx) => {
    console.log(`[bot] pre_checkout_query from userId=${ctx.from?.id}, payload=${ctx.preCheckoutQuery?.invoice_payload}`);
    await ctx.answerPreCheckoutQuery(true);
    console.log('[bot] pre_checkout_query approved');
  });

  // ── successful_payment ─────────────────────────────────────
  // Telegram sends this AFTER Stars are deducted — authoritative signal.
  bot.on('message:successful_payment', async (ctx) => {
    const payment = ctx.message.successful_payment;
    const userId  = ctx.from?.id;

    console.log(`[bot] successful_payment received — userId=${userId}, amount=${payment?.total_amount}, payload=${payment?.invoice_payload}`);

    if (!payment || !userId) {
      console.error('[bot] successful_payment: missing payment or userId', { payment, userId });
      return;
    }

    const userName   = ctx.from.first_name + (ctx.from.last_name ? ' ' + ctx.from.last_name : '');
    const userHandle = ctx.from.username ? `@${ctx.from.username}` : `id${userId}`;

    // ── Parse payload ───────────────────────────────────────
    let payload;
    try {
      payload = JSON.parse(payment.invoice_payload);
    } catch (e) {
      console.error('[bot] Could not parse invoice payload:', payment.invoice_payload, e.message);
      return;
    }

    if (!payload?.uid || payload.uid !== userId) {
      console.warn('[bot] uid mismatch in payload', { payloadUid: payload?.uid, userId });
      // Do NOT return — still process the payment
    }

    // ── Grant entitlement ───────────────────────────────────
    if (payload.type === 'unlimited') {
      grantPremium(userId);
      console.log(`[bot] Premium granted to user ${userId}`);
      await ctx.reply(
        '✨ *Unlimited splits unlocked!*\n\nReturn to PairSlice and enjoy — no more paywalls, ever.',
        { parse_mode: 'Markdown' }
      );
    } else if (payload.type === 'single') {
      grantSplit(userId);
      console.log(`[bot] +1 split credited to user ${userId}`);
      await ctx.reply(
        '⭐ *One split credited!*\n\nSwitch back to PairSlice — your split is ready.',
        { parse_mode: 'Markdown' }
      );
    } else if (payload.type === 'donate') {
      console.log(`[bot] Donation ${payment.total_amount} Stars received from user ${userId}`);
      await ctx.reply(
        '❤️ *Thank you for your support!*\n\nYour Stars mean a lot and help keep PairSlice free for everyone.',
        { parse_mode: 'Markdown' }
      );
    } else {
      console.warn('[bot] Unknown payload type:', payload.type);
    }

    // ── Notify owner ────────────────────────────────────────
    const ownerChatId = process.env.OWNER_CHAT_ID;
    if (!ownerChatId) {
      console.warn('[bot] OWNER_CHAT_ID not set — skipping owner notification');
      return;
    }

    let text;
    if (payload.type === 'donate') {
      text =
        `⭐ *Новый донат!*\n\n` +
        `👤 ${userName} (${userHandle})\n` +
        `💫 ${payment.total_amount} Stars`;
    } else {
      const emoji   = payload.type === 'unlimited' ? '🎉' : '⭐';
      const product = payload.type === 'unlimited' ? 'Unlimited (300 ⭐)' : 'One Split (75 ⭐)';
      text =
        `${emoji} *Новая покупка!*\n\n` +
        `👤 ${userName} (${userHandle})\n` +
        `📦 ${product}\n` +
        `💫 ${payment.total_amount} Stars`;
    }

    console.log(`[bot] Sending owner notification to chatId=${ownerChatId}…`);
    try {
      await bot.api.sendMessage(ownerChatId, text, { parse_mode: 'Markdown' });
      console.log('[bot] Owner notification sent successfully');
    } catch (e) {
      console.error('[bot] Failed to notify owner:', e.message, e);
    }
  });

  // ── error handler ──────────────────────────────────────────
  bot.catch((err) => {
    console.error('[bot] Unhandled error:', err.message);
    // Log the inner error too (Grammy wraps it in BotError)
    if (err.error) console.error('[bot] Inner error:', err.error);
  });

  return bot;
}
