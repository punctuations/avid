import { handle } from "../build/dev/javascript/avid/server/router.mjs";
import { createServer } from "../build/dev/javascript/avid/server/server_ffi.mjs";

export default async function handler(req, res) {
  handle(req, res);
}
