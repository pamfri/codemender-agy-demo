# Step 1: Threat Model (`examples/pillar-3-agent-skills/server.vulnerable.js`)

## 1. System Overview
`server.vulnerable.js` implements an invoice document reader (`readInvoiceVulnerable(requestedFilename)`) that retrieves invoice records from a simulated file store (`VIRTUAL_FS`) rooted at `INVOICES_BASE_DIR` (`/app/invoices`). It can be invoked both as a Node.js module and via CLI (`process.argv[2]`).

## 2. Untrusted Entry Points
- **Function Argument**: `requestedFilename` passed into `readInvoiceVulnerable(requestedFilename)`.
- **CLI Argument**: `process.argv[2]` when executed directly (`node server.vulnerable.js <filename>`).

## 3. Trust Boundaries
- **Boundary 1 (Caller / CLI Input -> Application Logic)**: Untrusted user-supplied `requestedFilename` crosses into the file path resolution logic without sanitization or canonical boundary enforcement.
- **Boundary 2 (Application Logic -> Virtual Filesystem Store `VIRTUAL_FS`)**: The application intends to restrict read access exclusively to documents within `/app/invoices/`, whereas `VIRTUAL_FS` also stores sensitive system files outside that directory (specifically `/etc/passwd`).

## 4. Sensitive Sinks & Vulnerability Analysis
- **Sensitive Sink**: `path.posix.join(INVOICES_BASE_DIR, requestedFilename)` (Line 17) followed by direct key lookup `VIRTUAL_FS[targetPath]` (Lines 19-20) and data return.
- **Vulnerability Class**: **CWE-22: Improper Limitation of a Pathname to a Restricted Directory ('Path Traversal')**.
- **Root Cause**: `path.posix.join('/app/invoices', requestedFilename)` normalizes relative segments (`..`) without verifying that the resulting path stays within `/app/invoices`.
- **Exploit Vector**: Passing `../../etc/passwd` resolves `targetPath` to `/etc/passwd`, escaping `/app/invoices` and leaking the contents of `/etc/passwd` (`root:x:0:0:...`).
