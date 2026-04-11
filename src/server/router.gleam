@target(javascript)
/// HTTP router for the avatar generation API (JavaScript/Node target).
///
/// Routes:
///   GET /avatar/:name             -> SVG (default)
///   GET /avatar/:name?format=svg  -> SVG, width/height from ?size=N (default 200)
///   GET /avatar/:name?format=png  -> PNG, size from ?size=N (default 200)
///   GET /avatar/:name?format=bmp  -> BMP, size from ?size=N (default 200)
///   GET /truchet/:name            -> Truchet SVG (default)
///   GET /truchet/:name?format=svg -> SVG, size from ?size=N (default 400)
///   GET /truchet/:name?format=png -> PNG, size from ?size=N (default 400)
///   GET /truchet/:name?format=bmp -> BMP, size from ?size=N (default 400)
///   GET /health                   -> 200 OK plaintext
import avid/avatar
@target(javascript)
import avid/render_bmp
@target(javascript)
import avid/render_png
@target(javascript)
import avid/render_svg
@target(javascript)
import avid/truchet
@target(javascript)
import gleam/int
@target(javascript)
import gleam/list
@target(javascript)
import gleam/option.{type Option, None, Some}
@target(javascript)
import gleam/result
@target(javascript)
import gleam/string

// ---------------------------------------------------------------------------
// FFI types - thin wrappers around Node's http.IncomingMessage / ServerResponse
// ---------------------------------------------------------------------------

pub type NodeRequest

pub type NodeResponse

// ---------------------------------------------------------------------------
// FFI bindings
// ---------------------------------------------------------------------------

@target(javascript)
@external(javascript, "./server_ffi.mjs", "createServer")
pub fn create_server(handler: fn(NodeRequest, NodeResponse) -> Nil) -> Nil

@target(javascript)
@external(javascript, "./server_ffi.mjs", "sendText")
pub fn send_text(
  res: NodeResponse,
  status: Int,
  content_type: String,
  body: String,
) -> Nil

@target(javascript)
@external(javascript, "./server_ffi.mjs", "sendBytes")
pub fn send_bytes(
  res: NodeResponse,
  status: Int,
  content_type: String,
  disposition: String,
  body: BitArray,
) -> Nil

@target(javascript)
@external(javascript, "./server_ffi.mjs", "getMethod")
pub fn get_method(req: NodeRequest) -> String

@target(javascript)
@external(javascript, "./server_ffi.mjs", "getUrl")
pub fn get_url(req: NodeRequest) -> String

// ---------------------------------------------------------------------------
// Router
// ---------------------------------------------------------------------------

@target(javascript)
pub fn handle(req: NodeRequest, res: NodeResponse) -> Nil {
  let method = get_method(req)
  let full_url = get_url(req)
  let #(path, query_string) = split_url(full_url)
  let segments = path_segments(path)

  case method, segments {
    "GET", ["health"] -> health(res)
    "GET", ["avatar", name] -> avatar_handler(res, name, query_string)
    "GET", ["truchet", name] -> truchet_handler(res, name, query_string)
    _, _ -> send_text(res, 404, "text/plain", "Not found")
  }
}

// ---------------------------------------------------------------------------
// Handlers
// ---------------------------------------------------------------------------

@target(javascript)
fn health(res: NodeResponse) -> Nil {
  send_text(res, 200, "text/plain", "ok")
}

@target(javascript)
fn avatar_handler(res: NodeResponse, name: String, query_string: String) -> Nil {
  let format = query_param(query_string, "format") |> option.unwrap("svg")
  let size_str = query_param(query_string, "size") |> option.unwrap("")
  let target = avatar.from_name(name) |> avatar.to_render_target()
  let size = int.parse(size_str) |> result.unwrap(200)

  case format {
    "svg" ->
      send_text(res, 200, "image/svg+xml", render_svg.render(target, size))
    "png" ->
      send_bytes(
        res,
        200,
        "image/png",
        "inline; filename=\"" <> name <> ".png\"",
        render_png.render(target, size),
      )
    "bmp" ->
      send_bytes(
        res,
        200,
        "image/bmp",
        "inline; filename=\"" <> name <> ".bmp\"",
        render_bmp.render(target, size),
      )
    _ ->
      send_text(
        res,
        422,
        "text/plain",
        "Unknown format \"" <> format <> "\". Use svg, png, or bmp.",
      )
  }
}

@target(javascript)
fn truchet_handler(res: NodeResponse, name: String, query_string: String) -> Nil {
  let format = query_param(query_string, "format") |> option.unwrap("svg")
  let size_str = query_param(query_string, "size") |> option.unwrap("")
  let target = truchet.from_name(name) |> truchet.to_render_target()
  let size = int.parse(size_str) |> result.unwrap(200)

  case format {
    "svg" ->
      send_text(res, 200, "image/svg+xml", render_svg.render(target, size))
    "png" ->
      send_bytes(
        res,
        200,
        "image/png",
        "inline; filename=\"" <> name <> ".png\"",
        render_png.render(target, size),
      )
    "bmp" ->
      send_bytes(
        res,
        200,
        "image/bmp",
        "inline; filename=\"" <> name <> ".bmp\"",
        render_bmp.render(target, size),
      )
    _ ->
      send_text(
        res,
        422,
        "text/plain",
        "Unknown format \"" <> format <> "\". Use svg, png, or bmp.",
      )
  }
}

// ---------------------------------------------------------------------------
// URL helpers
// ---------------------------------------------------------------------------

@target(javascript)
fn split_url(url: String) -> #(String, String) {
  case string.split_once(url, "?") {
    Ok(#(path, qs)) -> #(path, qs)
    Error(_) -> #(url, "")
  }
}

@target(javascript)
fn path_segments(path: String) -> List(String) {
  path
  |> string.split("/")
  |> list.filter(fn(s) { s != "" })
}

// ---------------------------------------------------------------------------
// Query param helpers
// ---------------------------------------------------------------------------

@target(javascript)
fn query_param(query_string: String, key: String) -> Option(String) {
  query_string
  |> string.split("&")
  |> find_param(key)
}

@target(javascript)
fn find_param(pairs: List(String), key: String) -> Option(String) {
  case pairs {
    [] -> None
    [pair, ..rest] ->
      case string.split_once(pair, "=") {
        Ok(#(k, v)) if k == key -> Some(v)
        _ -> find_param(rest, key)
      }
  }
}
