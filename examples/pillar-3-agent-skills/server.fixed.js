/**
 * Pillar 3 Example: Remediated Invoice Document Reader (server.fixed.js)
 */
const path = require('path');

const VIRTUAL_FS = {
  '/app/invoices/invoice-101.txt': 'INVOICE #101: Amount Due $250.00',
  '/etc/passwd': 'root:x:0:0:root:/root:/bin/bash\nappuser:x:1000:1000::/home/appuser:/bin/bash'
};

const INVOICES_BASE_DIR = '/app/invoices';

function readInvoiceFixed(requestedFilename) {
  const canonicalBase = path.posix.resolve(INVOICES_BASE_DIR);
  const resolvedTarget = path.posix.resolve(canonicalBase, requestedFilename);

  if (!resolvedTarget.startsWith(canonicalBase + '/')) {
    return {
      status: 403,
      pathResolved: resolvedTarget,
      error: 'Forbidden: Path traversal attempt detected outside INVOICES_BASE_DIR'
    };
  }

  if (VIRTUAL_FS[resolvedTarget]) {
    return { status: 200, pathResolved: resolvedTarget, content: VIRTUAL_FS[resolvedTarget] };
  }
  return { status: 404, pathResolved: resolvedTarget, error: 'Invoice not found' };
}

if (require.main === module) {
  const argFilename = process.argv[2] || 'invoice-101.txt';
  const result = readInvoiceFixed(argFilename);
  console.log(JSON.stringify(result));
}

module.exports = { readInvoiceFixed };
