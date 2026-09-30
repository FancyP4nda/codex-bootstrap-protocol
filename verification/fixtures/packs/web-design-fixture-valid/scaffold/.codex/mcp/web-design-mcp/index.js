#!/usr/bin/env node
// Minimal fixture MCP stdio stub for the T006 pack validator. Zero deps.
// Not a functional server; present only to give the validator a byte stream.
process.stdin.on("data", () => {});
process.stdout.write("");
