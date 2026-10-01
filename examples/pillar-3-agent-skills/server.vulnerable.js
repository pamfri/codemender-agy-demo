/**
 * Pillar 3 Example: Vulnerable Invoice Document Reader (server.vulnerable.js)
 */
const path = require('path');

const VIRTUAL_FS = {
  '/app/invoices/invoice-101.txt': 'INVOICE #101: Amount Due $250.00',
  '/etc/passwd': 'root:x:0:0:root:/root:/bin/bash\nappuser:x:1000:1000::/home/appuser:/bin/bash'
};

const INVOICES_BASE_DIR = '/app/invoices';

/**
 * ❌ VULNERABILITY (CWE-22: Path Traversal)
 */
function readInvoiceVulnerable(requestedFilename) {
  const targetPath = path.posix.join(INVOICES_BASE_DIR, requestedFilename);

  if (VIRTUAL_FS[targetPath]) {
    return { status: 200, pathResolved: targetPath, content: VIRTUAL_FS[targetPath] };
  }
  return { status: 404, pathResolved: targetPath, error: 'Invoice not found' };
}

if (require.main === module) {
  const argFilename = process.argv[2] || 'invoice-101.txt';
  const result = readInvoiceVulnerable(argFilename);
  console.log(JSON.stringify(result));
}

module.exports = { readInvoiceVulnerable };
