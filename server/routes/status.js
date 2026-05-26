import { Router } from 'express';
import { getUser } from '../lib/store.js';

const router = Router();

/**
 * GET /user/status?userId=<telegramUserId>
 *
 * Returns the premium state for a given Telegram user ID.
 * No HMAC validation here by design — the response reveals only
 * whether a stranger has premium, not any sensitive data.
 */
router.get('/user/status', (req, res) => {
  const userId = parseInt(req.query.userId, 10);

  if (!userId || isNaN(userId) || userId <= 0) {
    return res.status(400).json({ error: 'invalid userId' });
  }

  // Developer mode: owner gets unlimited access automatically
  const ownerChatId = process.env.OWNER_CHAT_ID
    ? parseInt(process.env.OWNER_CHAT_ID, 10)
    : null;

  if (ownerChatId && userId === ownerChatId) {
    return res.json({ isPremium: true, extraSplits: 999, isDevMode: true });
  }

  const u = getUser(userId);
  res.json({ isPremium: u.isPremium, extraSplits: u.extraSplits, isDevMode: false });
});

export default router;
