import { main } from "../build/dev/javascript/avid/avid.mjs";

let gleamHandler = null;

export default async function handler(req, res) {
  if (!gleamHandler) {
    globalThis.__vercel_capture = (h) => {
      gleamHandler = h;
    };
    await import("../build/dev/javascript/avid/avid.mjs");
  }
  gleamHandler(req, res);
}
