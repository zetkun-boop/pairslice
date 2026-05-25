// ─────────────────────────────────────────────────────────────
//  Telegram initData HMAC validation
//
//  Official spec: https://core.telegram.org/bots/webapps#validating-data-received-via-the-mini-app
//
//  Algorithm:
//    secret_key  = HMAC-SHA256("WebAppData", bot_token)
//    check_hash  = HMAC-SHA256(data_check_string, secret_key)
//
//  data_check_string = fields sorted alphabetically, joined with \n
//  (hash field itself is excluded from the string)
// ─────────────────────────────────────────────────────────────

import crypto from 'crypto';

/**
 * Validates a Telegram Mini App initData string.
 *
 * @param {string} initData  — raw initData from tg.initData
 * @param {string} botToken  — bot token from @BotFather
 * @returns {URLSearchParams} — parsed params if valid
 * @throws {Error}           — if hash is missing or invalid
 */
function validateInitData(initData, botToken) {
  if (!initData) throw new Error('initData is empty');

  const params = new URLSearchParams(initData);
  const hash = params.get('hash');
  if (!hash) throw new Error('missing hash in initData');
  params.delete('hash');

  // Build data-check-string: keys sorted alphabetically, joined with \n
  const dataCheckString = [...params.entries()]
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([k, v]) => `${k}=${v}`)
    .join('\n');

  // Step 1: derive secret key — key is the literal string "WebAppData"
  const secretKey = crypto
    .createHmac('sha256', 'WebAppData')
    .update(botToken)
    .digest();

  // Step 2: compute expected hash
  const expectedHash = crypto
    .createHmac('sha256', secretKey)
    .update(dataCheckString)
    .digest('hex');

  if (expectedHash !== hash) {
    throw new Error('initData hash mismatch — possible tampering');
  }

  return params;
}

export { validateInitData };
