/// HTTP router for the avatar generation API.
///
/// Routes:
///   GET /avatar/:name             -> SVG (default)
///   GET /avatar/:name?format=svg  -> SVG, width/height from ?size=N (default 200)
///   GET /avatar/:name?format=png  -> PNG, cell_size from ?size=N (default 40)
///   GET /avatar/:name?format=bmp  -> BMP, cell_size from ?size=N (default 40)
///   GET /health                   -> 200 OK plaintext
import avid/avatar
import avid/render_bmp
import avid/render_png
import avid/render_svg
import gleam/bytes_tree
import gleam/http.{Get}
import gleam/int
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import wisp.{type Request, type Response}

// ---------------------------------------------------------------------------
// Router
// ---------------------------------------------------------------------------

pub fn handle(req: Request) -> Response {
  case req.method, wisp.path_segments(req) {
    Get, ["health"] -> health()
    Get, ["avatar", name] -> avatar_handler(req, name)
    _, _ -> wisp.not_found()
  }
}

// ---------------------------------------------------------------------------
// Handlers
// ---------------------------------------------------------------------------

fn health() -> Response {
  wisp.ok()
  |> wisp.string_body("ok")
}

fn avatar_handler(req: Request, name: String) -> Response {
  let format = query_param(req, "format") |> option.unwrap("svg")
  let size_str = query_param(req, "size") |> option.unwrap("")
  let av = avatar.from_name(name)

  case format {
    "svg" -> {
      let size = int.parse(size_str) |> result.unwrap(200)
      let svg = render_svg.render(av, size)
      wisp.ok()
      |> wisp.set_header("content-type", "image/svg+xml")
      |> wisp.string_body(svg)
    }

    "png" -> {
      let cell = int.parse(size_str) |> result.unwrap(40)
      let bytes = render_png.render(av, cell)
      wisp.ok()
      |> wisp.set_header("content-type", "image/png")
      |> wisp.set_header(
        "content-disposition",
        "inline; filename=\"" <> name <> ".png\"",
      )
      |> wisp.set_body(wisp.Bytes(bytes_tree.from_bit_array(bytes)))
    }

    "bmp" -> {
      let cell = int.parse(size_str) |> result.unwrap(40)
      let bytes = render_bmp.render(av, cell)
      wisp.ok()
      |> wisp.set_header("content-type", "image/bmp")
      |> wisp.set_header(
        "content-disposition",
        "inline; filename=\"" <> name <> ".bmp\"",
      )
      |> wisp.set_body(wisp.Bytes(bytes_tree.from_bit_array(bytes)))
    }

    _ ->
      wisp.unprocessable_content()
      |> wisp.string_body(
        "Unknown format \"" <> format <> "\". Use svg, png, or bmp.",
      )
  }
}

// ---------------------------------------------------------------------------
// Query param helper
// ---------------------------------------------------------------------------

fn query_param(req: Request, key: String) -> option.Option(String) {
  let query = req.query |> option.unwrap("")
  query
  |> string.split("&")
  |> find_param(key)
}

fn find_param(pairs: List(String), key: String) -> option.Option(String) {
  case pairs {
    [] -> None
    [pair, ..rest] ->
      case string.split_once(pair, "=") {
        Ok(#(k, v)) if k == key -> Some(v)
        _ -> find_param(rest, key)
      }
  }
}
