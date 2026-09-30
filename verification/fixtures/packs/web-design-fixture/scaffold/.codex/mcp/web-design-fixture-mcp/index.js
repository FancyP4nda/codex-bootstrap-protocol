#!/usr/bin/env node
/*
 * TEST FIXTURE — NEVER RELEASE.
 *
 * Minimal runnable MCP server entry for the bootstrap kit's pack-install
 * verification suite (T012). Zero dependencies; newline-delimited JSON-RPC
 * over stdio. This is NOT a full MCP protocol implementation — it starts
 * cleanly, answers `initialize`, stays alive while stdin is open, and exits
 * 0 on stdin EOF, which is exactly the surface the delivery-contract checks
 * exercise (launch via `node <vendored path>` from the target-root
 * .mcp.json — never npx, never a registry fetch; see ADR-0001).
 *
 * Credential handling pattern (FR-006 / AC-011): the launch env carries
 * WEB_DESIGN_FIXTURE_TOKEN as a ${VAR} placeholder only. The server reports
 * presence/absence — it never logs the value.
 */
'use strict';

const SERVER_NAME = 'web-design-fixture-mcp';
const SERVER_VERSION = '0.0.0-fixture';

// Ready line goes to stderr: stdout is reserved for the JSON-RPC channel.
const tokenState = process.env.WEB_DESIGN_FIXTURE_TOKEN ? 'set' : 'unset';
process.stderr.write(
  `${SERVER_NAME}: fixture stdio server ready (WEB_DESIGN_FIXTURE_TOKEN: ${tokenState})\n`
);

let buffer = '';
process.stdin.setEncoding('utf8');

process.stdin.on('data', (chunk) => {
  buffer += chunk;
  let newline;
  while ((newline = buffer.indexOf('\n')) !== -1) {
    const line = buffer.slice(0, newline).trim();
    buffer = buffer.slice(newline + 1);
    if (!line) continue;

    let message;
    try {
      message = JSON.parse(line);
    } catch {
      // Fixture: ignore non-JSON input rather than crash.
      continue;
    }

    if (message && message.id !== undefined && message.method === 'initialize') {
      const reply = {
        jsonrpc: '2.0',
        id: message.id,
        result: {
          protocolVersion:
            (message.params && message.params.protocolVersion) || '2025-06-18',
          capabilities: {},
          serverInfo: { name: SERVER_NAME, version: SERVER_VERSION },
        },
      };
      process.stdout.write(JSON.stringify(reply) + '\n');
    }
  }
});

process.stdin.on('end', () => process.exit(0));
process.stdin.on('error', () => process.exit(1));
