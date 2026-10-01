# Step 4: Security Audit Report (`examples/pillar-3-agent-skills/server.vulnerable.js`)

## 1. Executive Summary
| Field | Details |
| :--- | :--- |
| **Target File** | `examples/pillar-3-agent-skills/server.vulnerable.js` |
| **Remediated File** | `examples/pillar-3-agent-skills/server.fixed.js` |
| **Vulnerability Class** | **CWE-22: Improper Limitation of a Pathname to a Restricted Directory ('Path Traversal')** |
| **Severity** | **HIGH** (Arbitrary file read outside restricted base directory `/app/invoices`) |
| **Status** | **REMEDIATED & VERIFIED** |

---

## 2. Root Cause Analysis
In `server.vulnerable.js`, `readInvoiceVulnerable(requestedFilename)` constructs the target file path using `path.posix.join(INVOICES_BASE_DIR, requestedFilename)` (line 17) and directly indexes into `VIRTUAL_FS[targetPath]` (line 19) without verifying that the normalized path remains inside `INVOICES_BASE_DIR` (`/app/invoices`).

When an attacker supplies relative dot-segment sequences such as `../../etc/passwd`, `path.posix.join('/app/invoices', '../../etc/passwd')` normalizes the path to `/etc/passwd`, crossing the intended directory boundary and exposing sensitive system file contents.

---

## 3. CodeMender CLI (`cm`) & Live PoC Verification Results

### 3.1 CodeMender CLI (`cm find` / `cm verify` / `cm fix`) Execution
Executed:
```bash
cm find examples/pillar-3-agent-skills/server.vulnerable.js --model gemini-3.7-flash -y --compact
cm verify <finding-id> -y
cm fix <finding-id> -y
```
- **Discovery & Scoping**: `cm` discovered and scoped `server.vulnerable.js` (1 target file) and analyzed the untrusted `requestedFilename` parameter flowing into `path.posix.join`.
- **Authentication**: Requires active Google Cloud Application Default Credentials (`gcloud auth application-default login --project=<YOUR_GCP_PROJECT_ID>`).

### 3.2 Live PoC Exploit Verification (`3_poc_exploit.sh`)
Executed `bash examples/pillar-3-agent-skills/3_poc_exploit.sh`:

1. **Unpatched Target (`server.vulnerable.js`) with Exploit Payload `../../etc/passwd`**:
   ```json
   {"status":200,"pathResolved":"/etc/passwd","content":"root:x:0:0:root:/root:/bin/bash\nappuser:x:1000:1000::/home/appuser:/bin/bash"}
   ```
   *Result*: **VULNERABLE** — `/etc/passwd` is leaked with HTTP status `200`.

2. **Remediated Target (`server.fixed.js`) with Exploit Payload `../../etc/passwd`**:
   ```json
   {"status":403,"pathResolved":"/etc/passwd","error":"Forbidden: Path traversal attempt detected outside INVOICES_BASE_DIR"}
   ```
   *Result*: **BLOCKED** — Traversal attempt outside `/app/invoices/` is rejected with HTTP status `403`.

3. **Regression Check (`server.fixed.js`) with Valid Input `invoice-101.txt`**:
   ```json
   {"status":200,"pathResolved":"/app/invoices/invoice-101.txt","content":"INVOICE #101: Amount Due $250.00"}
   ```
   *Result*: **PASS** — Legitimate invoice retrieval continues to work with zero regressions.

---

## 4. Applied Remediation Diff
```diff
--- examples/pillar-3-agent-skills/server.vulnerable.js
+++ examples/pillar-3-agent-skills/server.fixed.js
@@ -13,12 +13,19 @@
-function readInvoiceVulnerable(requestedFilename) {
-  const targetPath = path.posix.join(INVOICES_BASE_DIR, requestedFilename);
+function readInvoiceFixed(requestedFilename) {
+  const canonicalBase = path.posix.resolve(INVOICES_BASE_DIR);
+  const resolvedTarget = path.posix.resolve(canonicalBase, requestedFilename);
+
+  if (!resolvedTarget.startsWith(canonicalBase + '/')) {
+    return {
+      status: 403,
+      pathResolved: resolvedTarget,
+      error: 'Forbidden: Path traversal attempt detected outside INVOICES_BASE_DIR'
+    };
+  }
 
-  if (VIRTUAL_FS[targetPath]) {
-    return { status: 200, pathResolved: targetPath, content: VIRTUAL_FS[targetPath] };
+  if (VIRTUAL_FS[resolvedTarget]) {
+    return { status: 200, pathResolved: resolvedTarget, content: VIRTUAL_FS[resolvedTarget] };
   }
-  return { status: 404, pathResolved: targetPath, error: 'Invoice not found' };
+  return { status: 404, pathResolved: resolvedTarget, error: 'Invoice not found' };
 }
```

---

## 5. Residual Risks & Recommendations
1. **Symlink Traversal (Real Filesystems)**: When migrating from `VIRTUAL_FS` to a real POSIX filesystem (`fs.readFile`), `path.posix.resolve` alone does not resolve symbolic links. Use `fs.realpathSync` on both the base directory and the target path before checking prefix containment.
2. **Input Type & Character Allowlisting**: Validate that `requestedFilename` is a non-empty string matching a strict filename pattern (e.g., `/^invoice-[0-9]+\.txt$/`) to enforce defense-in-depth alongside canonical path verification.
3. **Information Disclosure in Error Responses**: Omit `pathResolved` from `403`/`404` responses in production APIs to avoid leaking internal filesystem layout to callers.
