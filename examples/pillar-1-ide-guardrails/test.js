#!/usr/bin/env node
/**
 * Pillar 1 Verification & Regression Test Suite (test.js)
 * Invoked automatically by CodeMender `build.command` during `cm fix`.
 */
const assert = require('assert');
const { handleUserLookupVulnerable } = require('./app.js');
const { handleUserLookupFixed } = require('./app.fixed.js');

console.log('Running Pillar 1 (IDE Guardrails) Security & Regression Tests...');

const sqliPayload = { username: "admin' OR '1'='1" };
const vulnResult = handleUserLookupVulnerable(sqliPayload);
assert.strictEqual(vulnResult.records.length, 2);

const fixedSqliResult = handleUserLookupFixed(sqliPayload);
assert.strictEqual(fixedSqliResult.records.length, 0);

const xssPayload = { username: '<script>alert("xss")</script>' };
const fixedXssResult = handleUserLookupFixed(xssPayload);
assert.ok(!fixedXssResult.htmlBanner.includes('<script>'));
assert.ok(fixedXssResult.htmlBanner.includes('&lt;script&gt;'));

const legitQuery = { username: 'alice' };
const fixedLegitResult = handleUserLookupFixed(legitQuery);
assert.strictEqual(fixedLegitResult.records.length, 1);
assert.strictEqual(fixedLegitResult.records[0].username, 'alice');
assert.strictEqual(fixedLegitResult.htmlBanner, '<h1>Welcome back, alice!</h1>');

console.log('  ✔ SQL Injection exploit blocked (CWE-89 verified)');
console.log('  ✔ Reflected XSS payload escaped (CWE-79 verified)');
console.log('  ✔ Normal functional user lookup passed zero-regression check');
