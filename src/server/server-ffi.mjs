// server_ffi.mjs
import http from "node:http";

const PORT = process.env.PORT ?? 3000;

export function createServer(handler) {
  if (globalThis.__vercel_capture) {
    // hand the handler back instead of listening
    globalThis.__vercel_capture(handler);
    return;
  }
  // Local dev mode
  import("node:http").then(({ default: http }) => {
    const PORT = process.env.PORT ?? 3000;
    http
      .createServer((req, res) => handler(req, res))
      .listen(PORT, () => console.log(`Listening on http://localhost:${PORT}`));
  });
}

export function getMethod(req) {
  return req.method ?? "GET";
}

export function getUrl(req) {
  return req.url ?? "/";
}

export function sendText(res, status, contentType, body) {
  res.writeHead(status, {
    "Content-Type": contentType,
    "Content-Length": Buffer.byteLength(body, "utf8"),
  });
  res.end(body);
}

export function sendBytes(res, status, contentType, disposition, bitArray) {
  const buf = Buffer.from(
    bitArray.buffer,
    bitArray.byteOffset,
    bitArray.byteLength,
  );
  res.writeHead(status, {
    "Content-Type": contentType,
    "Content-Disposition": disposition,
    "Content-Length": buf.byteLength,
  });
  res.end(buf);
}
