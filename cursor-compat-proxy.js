#!/usr/bin/env node
/**
 * Cursor compatibility proxy.
 * - Listen on 8317 and forward to CLIProxyAPI (default 8318)
 * - Normalize SSE framing for /v1/chat/completions and /v1/responses
 * - Optionally map "safe" Cursor model aliases to upstream models
 */

const http = require("http");

function now() {
  return new Date().toISOString();
}

function getEnvInt(name, fallback) {
  const raw = process.env[name];
  if (!raw) return fallback;
  const n = Number(raw);
  return Number.isFinite(n) ? n : fallback;
}

function setCors(res) {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Headers", "*");
  res.setHeader("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS");
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on("data", (c) => chunks.push(c));
    req.on("end", () => resolve(Buffer.concat(chunks)));
    req.on("error", reject);
  });
}

function safeHeaderValue(value) {
  if (Array.isArray(value)) return value.join(", ");
  if (typeof value === "string") return value;
  if (typeof value === "number") return String(value);
  return "";
}

function parseModelMap(raw) {
  const map = new Map();
  if (!raw) return map;
  for (const part of raw.split(",")) {
    const [from, to] = part.split("=").map((s) => s.trim());
    if (from && to) map.set(from, to);
  }
  return map;
}

const MODEL_MAP = parseModelMap(process.env.CURSOR_COMPAT_MODEL_MAP || "");
const FORCE_MODEL = (process.env.CURSOR_COMPAT_FORCE_MODEL || "").trim();
const FORCE_KEY = (process.env.CURSOR_COMPAT_FORCE_KEY || "cursor-only").trim();
const FORCE_ALL = /^(1|true|yes)$/i.test(
  String(process.env.CURSOR_COMPAT_FORCE_ALL || "")
);

function mapModel(name) {
  if (!name) return name;
  return MODEL_MAP.get(name) || name;
}

function normalizeHeaders(headers, rawHeaders) {
  const out = {};
  if (headers) {
    for (const [k, v] of Object.entries(headers)) {
      out[String(k).toLowerCase()] = Array.isArray(v) ? v.join(", ") : String(v);
    }
  }
  if (Array.isArray(rawHeaders)) {
    for (let i = 0; i + 1 < rawHeaders.length; i += 2) {
      const k = String(rawHeaders[i]).toLowerCase();
      const v = String(rawHeaders[i + 1]);
      out[k] = v;
    }
  }
  return out;
}

function parseAuthToken(headers, rawHeaders) {
  const map = normalizeHeaders(headers, rawHeaders);
  const rawAuth = map["authorization"];
  if (rawAuth) {
    const m = String(rawAuth).match(/Bearer\s+(.+)/i);
    return m ? m[1].trim() : String(rawAuth).trim();
  }

  const apiKey =
    map["x-api-key"] ||
    map["api-key"] ||
    map["openai-api-key"] ||
    map["x-openai-api-key"] ||
    map["x-openai-key"] ||
    map["openai-key"];
  return apiKey ? String(apiKey).trim() : "";
}

function shouldForce(headers, rawHeaders) {
  if (FORCE_ALL) return true;
  if (!FORCE_KEY) return false;
  const token = parseAuthToken(headers, rawHeaders);
  return token === FORCE_KEY;
}

function resolveUpstreamModel(clientModel, headers, rawHeaders) {
  if (!shouldForce(headers, rawHeaders)) return clientModel;
  return FORCE_MODEL || mapModel(clientModel) || clientModel;
}

function findEventSeparator(buffer) {
  const idxR = buffer.indexOf("\r\n\r\n");
  const idxN = buffer.indexOf("\n\n");
  if (idxR === -1 && idxN === -1) return { idx: -1, len: 0 };
  if (idxR === -1) return { idx: idxN, len: 2 };
  if (idxN === -1) return { idx: idxR, len: 4 };
  return idxR < idxN ? { idx: idxR, len: 4 } : { idx: idxN, len: 2 };
}

function writeSse(res, lines) {
  res.write(lines.join("\n") + "\n\n");
}

function rewriteModelFields(obj, clientModel) {
  if (!clientModel || !obj || typeof obj !== "object") return;
  if (typeof obj.model === "string") obj.model = clientModel;
  if (obj.response && typeof obj.response.model === "string") {
    obj.response.model = clientModel;
  }
}

function redactToken(token) {
  if (!token) return "(none)";
  const t = String(token);
  if (t.length <= 8) return `${t[0]}***${t.slice(-1)}`;
  return `${t.slice(0, 4)}...${t.slice(-4)}`;
}

function proxyGeneric(req, res, upstream) {
  const reqId = `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;
  console.log(`[${now()}] [${reqId}] ${req.method} ${req.url} -> upstream`);

  const upstreamReq = http.request(
    {
      hostname: upstream.host,
      port: upstream.port,
      method: req.method,
      path: req.url,
      headers: { ...req.headers },
    },
    (upstreamRes) => {
      res.statusCode = upstreamRes.statusCode || 502;
      for (const [k, v] of Object.entries(upstreamRes.headers)) {
        if (typeof v !== "undefined") res.setHeader(k, v);
      }
      setCors(res);
      console.log(
        `[${now()}] [${reqId}] <- ${upstreamRes.statusCode} ${safeHeaderValue(
          upstreamRes.headers["content-type"]
        )}`
      );
      upstreamRes.pipe(res);
    }
  );

  upstreamReq.on("error", (err) => {
    res.statusCode = 502;
    setCors(res);
    res.setHeader("Content-Type", "application/json");
    res.end(JSON.stringify({ error: { message: String(err) } }));
  });

  req.pipe(upstreamReq);
}

function handleStreamingResponse(upstreamRes, res, clientModel) {
  const contentType = String(upstreamRes.headers["content-type"] || "");
  const isEventStream = contentType.includes("text/event-stream");

  if (!isEventStream) {
    upstreamRes.pipe(res);
    return;
  }

  // Do not forward content-length when we rewrite SSE.
  for (const [k, v] of Object.entries(upstreamRes.headers)) {
    if (k.toLowerCase() === "content-length") continue;
    if (typeof v !== "undefined") res.setHeader(k, v);
  }
  setCors(res);
  if (res.flushHeaders) res.flushHeaders();

  let buffer = "";
  let sawDone = false;
  let eventsForwarded = 0;

  function processBufferedEvents({ flushTrailing } = { flushTrailing: false }) {
    if (flushTrailing && buffer.length > 0) buffer += "\n\n";

    while (true) {
      const sep = findEventSeparator(buffer);
      if (sep.idx === -1) break;
      const rawEvent = buffer.slice(0, sep.idx);
      buffer = buffer.slice(sep.idx + sep.len);

      const outLines = [];
      for (const line of rawEvent.split(/\r?\n/)) {
        if (line.startsWith("data:")) {
          const data = line.slice(5).trimStart();
          if (!data) continue;
          if (data === "[DONE]") {
            sawDone = true;
            outLines.push("data: [DONE]");
            continue;
          }
          try {
            const obj = JSON.parse(data);
            rewriteModelFields(obj, clientModel);
            outLines.push(`data: ${JSON.stringify(obj)}`);
          } catch {
            outLines.push(`data: ${data}`);
          }
        } else if (
          line.startsWith("event:") ||
          line.startsWith("id:") ||
          line.startsWith("retry:") ||
          line.startsWith(":")
        ) {
          outLines.push(line);
        }
      }

      if (outLines.length > 0) {
        writeSse(res, outLines);
        eventsForwarded += 1;
      }
    }
  }

  upstreamRes.setEncoding("utf8");
  upstreamRes.on("data", (chunk) => {
    buffer += chunk;
    processBufferedEvents();
  });

  upstreamRes.on("end", () => {
    processBufferedEvents({ flushTrailing: true });
    if (!sawDone) writeSse(res, ["data: [DONE]"]);
    console.log(
      `[${now()}] stream complete events=${eventsForwarded} sawDone=${sawDone}`
    );
    res.end();
  });
}

async function proxyJsonWithOptionalRewrite(req, res, upstream, bodyBuf, pathLabel) {
  let bodyJson = null;
  try {
    bodyJson = JSON.parse(bodyBuf.toString("utf8"));
  } catch {
    bodyJson = null;
  }

  const clientModel = typeof bodyJson?.model === "string" ? bodyJson.model : undefined;
  const authToken = parseAuthToken(req.headers, req.rawHeaders);
  const forceApplied = shouldForce(req.headers, req.rawHeaders);
  const upstreamModel = resolveUpstreamModel(clientModel, req.headers, req.rawHeaders);
  if (bodyJson && upstreamModel) {
    bodyJson.model = upstreamModel;
  }

  const wantsStream = !!bodyJson?.stream;
  const nextBody = bodyJson ? Buffer.from(JSON.stringify(bodyJson)) : bodyBuf;

  const reqId = `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;
  console.log(
    `[${now()}] [${reqId}] ${req.method} ${req.url} stream=${wantsStream} model=${
      clientModel || "(none)"
    } mapped=${upstreamModel || "(none)"} forced=${FORCE_MODEL || "(none)"} forceKey=${FORCE_KEY || "(none)"} forceAll=${FORCE_ALL} forceApplied=${forceApplied} auth=${redactToken(authToken)}`
  );

  const upstreamReq = http.request(
    {
      hostname: upstream.host,
      port: upstream.port,
      method: req.method,
      path: req.url,
      headers: {
        ...(() => {
          const headers = { ...req.headers };
          delete headers["content-length"];
          delete headers["transfer-encoding"];
          return headers;
        })(),
        "content-length": Buffer.byteLength(nextBody),
      },
    },
    (upstreamRes) => {
      res.statusCode = upstreamRes.statusCode || 502;
      const contentType = String(upstreamRes.headers["content-type"] || "");
      const isEventStream = contentType.includes("text/event-stream");

      if (wantsStream && isEventStream) {
        handleStreamingResponse(upstreamRes, res, clientModel);
        return;
      }

      // Non-stream: optionally rewrite model fields in JSON.
      if (clientModel && contentType.includes("application/json")) {
        const chunks = [];
        upstreamRes.on("data", (c) => chunks.push(c));
        upstreamRes.on("end", () => {
          let outBuf = Buffer.concat(chunks);
          try {
            const obj = JSON.parse(outBuf.toString("utf8"));
            rewriteModelFields(obj, clientModel);
            outBuf = Buffer.from(JSON.stringify(obj));
          } catch {
            // keep original
          }
          for (const [k, v] of Object.entries(upstreamRes.headers)) {
            if (k.toLowerCase() === "content-length") continue;
            if (typeof v !== "undefined") res.setHeader(k, v);
          }
          res.setHeader("Content-Length", String(outBuf.length));
          setCors(res);
          res.end(outBuf);
        });
        return;
      }

      for (const [k, v] of Object.entries(upstreamRes.headers)) {
        if (typeof v !== "undefined") res.setHeader(k, v);
      }
      setCors(res);
      upstreamRes.pipe(res);
    }
  );

  upstreamReq.on("error", (err) => {
    res.statusCode = 502;
    setCors(res);
    res.setHeader("Content-Type", "application/json");
    res.end(JSON.stringify({ error: { message: String(err) } }));
  });

  upstreamReq.end(nextBody);
}

async function main() {
  const listenPort = getEnvInt("CURSOR_COMPAT_LISTEN_PORT", 8317);
  const upstream = {
    host: process.env.CURSOR_COMPAT_UPSTREAM_HOST || "127.0.0.1",
    port: getEnvInt("CURSOR_COMPAT_UPSTREAM_PORT", 8318),
  };

  const server = http.createServer(async (req, res) => {
    if (req.method === "OPTIONS") {
      res.statusCode = 204;
      setCors(res);
      res.end();
      return;
    }

    if (req.method === "GET" && req.url === "/") {
      res.statusCode = 200;
      setCors(res);
      res.setHeader("Content-Type", "application/json");
      res.end(JSON.stringify({ ok: true, upstream }));
      return;
    }

    if (
      req.method === "POST" &&
      (req.url?.startsWith("/v1/chat/completions") ||
        req.url?.startsWith("/v1/responses"))
    ) {
      const bodyBuf = await readBody(req);
      await proxyJsonWithOptionalRewrite(req, res, upstream, bodyBuf, req.url);
      return;
    }

    proxyGeneric(req, res, upstream);
  });

  server.listen(listenPort, "127.0.0.1", () => {
    console.log(
      `[cursor-compat-proxy] listening on http://127.0.0.1:${listenPort} -> http://${upstream.host}:${upstream.port}`
    );
  });
}

main().catch((err) => {
  console.error("[cursor-compat-proxy] fatal:", err);
  process.exit(1);
});
