#!/usr/bin/env node
// SPDX-License-Identifier: AGPL-3.0-only
// stdio <-> Streamable HTTP bridge for the Nitter agent API.
//   NITTER_BASE_URL   e.g. http://192.168.1.10:8080   (required)
//   NITTER_API_TOKEN  bearer token                     (required)
// Reads newline-delimited JSON-RPC from stdin, POSTs each message to
// <base>/mcp and writes the response to stdout. stdout carries protocol
// messages only; diagnostics go to stderr.
import { createInterface } from "node:readline";

const base = (process.env.NITTER_BASE_URL || "").replace(/\/+$/, "");
const token = process.env.NITTER_API_TOKEN || "";
if (!base || !token) {
  console.error("nitter-mcp: set NITTER_BASE_URL and NITTER_API_TOKEN");
  process.exit(2);
}
const endpoint = `${base}/mcp`;
const timeoutMs = Number(process.env.NITTER_TIMEOUT_MS || 60000);
let protocolVersion = "";

const out = (obj) => process.stdout.write(JSON.stringify(obj) + "\n");
const fail = (id, code, message) =>
  id === undefined || id === null ? undefined : out({ jsonrpc: "2.0", id, error: { code, message } });

async function forward(line) {
  let msg;
  try {
    msg = JSON.parse(line);
  } catch {
    return out({ jsonrpc: "2.0", id: null, error: { code: -32700, message: "Parse error" } });
  }
  const id = Array.isArray(msg) ? undefined : msg.id;
  const headers = {
    "content-type": "application/json",
    accept: "application/json, text/event-stream",
    authorization: `Bearer ${token}`,
  };
  if (protocolVersion) headers["mcp-protocol-version"] = protocolVersion;

  let res, text;
  try {
    res = await fetch(endpoint, {
      method: "POST", headers, body: line, signal: AbortSignal.timeout(timeoutMs),
    });
    text = await res.text();
  } catch (e) {
    return fail(id, -32000, `Cannot reach ${endpoint}: ${e.cause?.code || e.message}`);
  }

  if (res.status === 202 || text.trim() === "") return;   // notification accepted
  let body;
  try {
    body = JSON.parse(text);
  } catch {
    return fail(id, -32000, `Unexpected non-JSON response (HTTP ${res.status})`);
  }
  if (msg.method === "initialize" && body?.result?.protocolVersion) {
    protocolVersion = body.result.protocolVersion;
  }
  // HTTP-level errors (401, 429, ...) carry an error body with id:null. Clients
  // match responses by id, so re-address it to the request that failed.
  if (!res.ok && id !== undefined) {
    const message = body?.error?.message || `HTTP ${res.status}`;
    return out({ jsonrpc: "2.0", id, error: { ...(body?.error || {}), code: -32000, message } });
  }
  out(body);
}

const rl = createInterface({ input: process.stdin, crlfDelay: Infinity });
// Strictly sequential: `initialize` must finish (so the negotiated protocol
// version is known) before later requests are sent.
let chain = Promise.resolve();
rl.on("line", (line) => {
  if (!line.trim()) return;
  chain = chain.then(() => forward(line)).catch((e) => console.error("nitter-mcp:", e));
});
rl.on("close", async () => { await chain; process.exit(0); });
