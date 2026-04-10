import { handle } from "../build/dev/javascript/avid/server/router.mjs";

export default async function handler(req, res) {
  handle(req, res);
}
