/// SVG renderer for avatars.
///
/// Produces a self-contained SVG string with a <rect> per grid cell.
import avid/avatar.{type Avatar, type Color}
import gleam/int
import gleam/list
import gleam/string

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Render an Avatar as an SVG string.
///
/// The viewBox is always 5x5 units. Use `size` to set the rendered pixel
/// dimensions via width/height attributes (e.g. 200 → "200px").
pub fn render(av: Avatar, size: Int) -> String {
  let bg = color_to_hex(av.bg)
  let fg = color_to_hex(av.fg)
  let size_str = int.to_string(size)
  let cells = render_cells(av.grid, fg)

  string.join(
    [
      "<svg xmlns=\"http://www.w3.org/2000/svg\"",
      "  width=\"" <> size_str <> "\" height=\"" <> size_str <> "\"",
      "  viewBox=\"0 0 5 5\">",
      "  <rect width=\"5\" height=\"5\" fill=\"" <> bg <> "\"/>",
      cells,
      "</svg>",
    ],
    "\n",
  )
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

fn render_cells(grid: List(Bool), fg: String) -> String {
  grid
  |> list.index_map(fn(filled, i) {
    case filled {
      False -> ""
      True -> {
        let col = i % 5
        let row = i / 5
        "<rect x=\""
        <> int.to_string(col)
        <> "\" y=\""
        <> int.to_string(row)
        <> "\" width=\"1\" height=\"1\" fill=\""
        <> fg
        <> "\"/>"
      }
    }
  })
  |> list.filter(fn(s) { s != "" })
  |> string.join("\n  ")
}

fn color_to_hex(c: Color) -> String {
  "#" <> pad_hex(c.r) <> pad_hex(c.g) <> pad_hex(c.b)
}

fn pad_hex(n: Int) -> String {
  let clamped = int.clamp(n, 0, 255)
  let s = int.to_base16(clamped)
  case string.length(s) {
    1 -> "0" <> s
    _ -> s
  }
}
