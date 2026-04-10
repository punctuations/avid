import { main } from "../build/dev/javascript/avid/avid.mjs";

// Replace the createServer FFI to just capture the handler
let gleamHandler = null;

// Patch server_ffi.mjs behaviour at import time
globalThis.__vercel_capture = (handler) => {
  gleamHandler = handler;
};

export default async function handler(req, res) {
  if (!gleamHandler) {
    // initialise — runs main() which calls createServer, which we intercept
    await import("../build/dev/javascript/avid/avid.mjs");
  }
  gleamHandler(req, res);
}
