// ─────────────────────────────────────────────────────────────
//  In-memory user store (MVP)
//
//  Structure:  Map<userId: number, UserRecord>
//
//  UserRecord:
//    isPremium   — true after "unlimited" Stars purchase
//    extraSplits — consumable credits from "single" purchases
//
//  ⚠️  Data resets on server restart.
//  Post-MVP: replace with Railway PostgreSQL — one table, two columns.
// ─────────────────────────────────────────────────────────────

/** @type {Map<number, {isPremium: boolean, extraSplits: number}>} */
const users = new Map();

/**
 * Returns (or lazily creates) a user record.
 * @param {number} userId
 */
function getUser(userId) {
  if (!users.has(userId)) {
    users.set(userId, { isPremium: false, extraSplits: 0 });
  }
  return users.get(userId);
}

/**
 * Credits one consumable split to the user.
 * @param {number} userId
 */
function grantSplit(userId) {
  const u = getUser(userId);
  u.extraSplits += 1;
}

/**
 * Marks the user as having lifetime unlimited splits.
 * @param {number} userId
 */
function grantPremium(userId) {
  const u = getUser(userId);
  u.isPremium = true;
  u.extraSplits = 0; // irrelevant once premium
}

export { getUser, grantSplit, grantPremium };
