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
  // Sends a welcome message with a "Open Mini App" button.
  bot.command('start', async (ctx) => {
    const kb = new InlineKeyboard().webApp('Open PairSlice ✂️', frontendUrl);
    await ctx.reply(
      '👋 Welcome to *PairSlice*!\n\n' +
      'Split any image in half for a seamless Threads carousel.\n\n' +
      '• 1 free split to try\n' +
      '• ⭐ 75 Stars = one more split (~$0.99)\n' +
      '• ⭐ 300 Stars = unlimited forever (~$3.99)',
      { parse_mode: 'Markdown', reply_markup: kb }
    );
  });

  // ── pre_checkout_query ─────────────────────────────────────
  // Telegram sends this BEFORE charging the user.
  // Must be answered within 10 seconds (Grammy handles timing automatically).
  // We always approve — digital goods have no inventory to check.
  bot.on('pre_checkout_query', async (ctx) => {
    await ctx.answerPreCheckoutQuery(true);
  });

  // ── successful_payment ─────────────────────────────────────
  // Telegram sends this AFTER the Stars have been deducted.
  // This is the authoritative signal — update the store here.
  bot.on('message:successful_payment', async (ctx) => {
    const payment = ctx.message.successful_payment;
    const userId = ctx.from.id;
    const userName = ctx.from.first_name + (ctx.from.last_name ? ' ' + ctx.from.last_name : '');
    const userHandle = ctx.from.username ? `@${ctx.from.username}` : `id${userId}`;

    let payload;
    try {
      payload = JSON.parse(payment.invoice_payload);
    } catch {
      console.error('[bot] Could not parse invoice payload:', payment.invoice_payload);
      return;
    }

    if (!payload?.uid || payload.uid !== userId) {
      console.warn('[bot] uid mismatch in payload', { payload, userId });
    }

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
    } else {
      console.warn('[bot] Unknown payload type:', payload.type);
    }

    // ── Notify owner ──────────────────────────────────────────
    const ownerChatId = process.env.OWNER_CHAT_ID;
    if (ownerChatId) {
      const emoji  = payload.type === 'unlimited' ? '🎉' : '⭐';
      const product = payload.type === 'unlimited' ? 'Unlimited (300 ⭐)' : 'One Split (75 ⭐)';
      const text =
        `${emoji} *Новая покупка!*\n\n` +
        `👤 ${userName} (${userHandle})\n` +
        `📦 ${product}\n` +
        `💫 ${payment.total_amount} Stars`;
      try {
        await bot.api.sendMessage(ownerChatId, text, { parse_mode: 'Markdown' });
      } catch (e) {
        console.error('[bot] Failed to notify owner:', e.message);
      }
    }
  });

  // ── error handler ──────────────────────────────────────────
  bot.catch((err) => {
    console.error('[bot] Unhandled error:', err.message);
  });

  return bot;
}
