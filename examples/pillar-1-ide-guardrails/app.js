/**
 * Pillar 1 Example: Vulnerable User Lookup Service (app.js)
 * Demonstrates real-time SecureCoder IDE diagnostics & CodeLens actions.
 */

// [STICKY SUPPRESSION EXAMPLE]
// The trimmed line below is hashed (SHA-256) in `.codemender/suppressions.json`.
// Shifting its line number will NOT break the suppression, but editing the string will re-trigger CWE-798.
const LOCAL_MOCK_SIGNATURE_KEY = 'dev-only-non-prod-key-0000';

/**
 * Simulated in-memory database driver for self-contained execution.
 */
class MockDatabase {
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
    const targetUsername = String(params && params[0]);
    return this.users.filter(u => u.username === targetUsername);
  }

  // Vulnerable raw SQL execution simulator
  rawQuery(sqlString) {
    if (sqlString.includes("' OR '1'='1") || sqlString.includes('" OR "1"="1')) {
      return this.users;
    }
    const match = sqlString.match(/username\s*=\s*'([^']*)'/);
    if (!match) return [];
    return this.users.filter(u => u.username === match[1]);
  }
}

const db = new MockDatabase();

/**
 * VULNERABLE HANDLER: Contains CWE-89 (SQL Injection) and CWE-79 (Reflected XSS)
 */
function handleUserLookupVulnerable(reqQuery) {
  const username = reqQuery.username || 'guest';

  const sqlTemplate = 'SELECT id, username, role FROM users WHERE username = ?';
  const records = db.parameterizedQuery(sqlTemplate, [username]);

  // ❌ VULNERABILITY 2 (CWE-79: Reflected XSS)
  const htmlBanner = `<h1>Welcome back, ${username}!</h1>`;

  return {
    status: 200,
    records,
    htmlBanner,
    signatureUsed: LOCAL_MOCK_SIGNATURE_KEY
  };
}

module.exports = { handleUserLookupVulnerable, MockDatabase };
