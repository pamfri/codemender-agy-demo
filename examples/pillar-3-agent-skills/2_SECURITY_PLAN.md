# Step 2: Security Implementation Plan (`examples/pillar-3-agent-skills/server.vulnerable.js`)

## 1. Remediation Pattern: Canonical Path Resolution & Prefix Boundary Enforcement
To eliminate **CWE-22 (Path Traversal)** in `readInvoiceVulnerable`, replace `path.posix.join` with canonical path resolution and strict base-directory prefix validation:

1. **Canonicalize Base Directory**:
   Resolve the base directory to a canonical absolute path and append a trailing separator (`/`) to prevent partial-prefix bypasses (e.g., `/app/invoices-backup`):
   ```javascript
   const canonicalBase = path.posix.resolve(INVOICES_BASE_DIR);
   ```
2. **Canonicalize Target Path**:
   Resolve the user-supplied filename against `canonicalBase`:
   ```javascript
   const resolvedTarget = path.posix.resolve(canonicalBase, String(requestedFilename));
   ```
3. **Enforce Directory Containment Check**:
   Verify that `resolvedTarget` strictly starts with `canonicalBase + '/'`. Reject any out-of-bounds path with HTTP `403 Forbidden` before accessing `VIRTUAL_FS`:
   ```javascript
   if (!resolvedTarget.startsWith(canonicalBase + '/')) {
     return {
       status: 403,
       pathResolved: resolvedTarget,
       error: 'Forbidden: Path traversal attempt detected outside INVOICES_BASE_DIR'
     };
   }
   ```

## 2. Verification Criteria
1. **Static & Taint Analysis (`cm find`)**:
   - Running `cm find examples/pillar-3-agent-skills/server.vulnerable.js --model gemini-3.7-flash -y --compact` identifies the CWE-22 Path Traversal vulnerability.
2. **Dynamic PoC Verification (`cm verify`)**:
   - Running `cm verify <finding_id> -y` executes a live Proof-of-Concept exploit demonstrating arbitrary file read (`../../etc/passwd`) on the unpatched target.
3. **Automated Remediation & Regression Check (`cm fix`)**:
   - Running `cm fix <finding_id> -y` generates and validates a patch that neutralizes the PoC exploit while preserving valid invoice lookups (`invoice-101.txt` -> `status: 200`).
   - Traversal payloads (`../../etc/passwd`, `/etc/passwd`, `../invoices-other/file.txt`) are blocked (`status: 403` / `404`) and never leak `/etc/passwd`.
