/**
 * Pillar 1 Example: Remediated User Lookup Service (app.fixed.js)
 * Demonstrates CodeMender / SecureCoder patch for CWE-89 (SQLi) and CWE-79 (XSS).
 */

const LOCAL_MOCK_SIGNATURE_KEY = 'dev-only-non-prod-key-0000';

function escapeHtml(unsafeStr) {
  return String(unsafeStr)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

class SecureMockDatabase {
  constructor() {
    this.users = [
      { id: 1, username: 'alice', role: 'admin', email: 'alice@example.com' },
      { id: 2, username: 'bob', role: 'user', email: 'bob@example.com' }
    ];
  }

  parameterizedQuery(sqlTemplate, params) {
    if (sqlTemplate !== 'SELECT id, username, role FROM users WHERE username = ?') {
      throw new Error('Unsupported query template');
    }
    const targetUsername = String(params[0]);
    return this.users.filter(u => u.username === targetUsername);
  }
}

const db = new SecureMockDatabase();

function handleUserLookupFixed(reqQuery) {
  const username = reqQuery.username || 'guest';
  const sqlTemplate = 'SELECT id, username, role FROM users WHERE username = ?';
  const records = db.parameterizedQuery(sqlTemplate, [username]);
  const safeUsername = escapeHtml(username);
  const htmlBanner = `<h1>Welcome back, ${safeUsername}!</h1>`;

  return {
    status: 200,
    records,
    htmlBanner,
    signatureUsed: LOCAL_MOCK_SIGNATURE_KEY
  };
}

module.exports = { handleUserLookupFixed, escapeHtml };
