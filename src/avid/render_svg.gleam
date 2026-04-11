/// SVG renderer.
///
/// Uses the tile fn from RenderTarget to emit vector paths.
/// Avatar cells are rects, truchet cells are arc paths.
import avid/color.{type Color}
import avid/render.{type RenderTarget, ArcDiagA, ArcDiagB, Empty, Solid}
import gleam/int
import gleam/list
import gleam/string

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

pub fn render(target: RenderTarget, size: Int) -> String {
  let size_str = int.to_string(size)
  let vb_w = target.grid_w * 100
  let vb_h = target.grid_h * 100
  let vb_w_str = int.to_string(vb_w)
  let vb_h_str = int.to_string(vb_h)
  let bg_hex = color_to_hex(target.bg)
  let fg_hex = color_to_hex(target.fg)

  let cells =
    range(target.grid_h)
    |> list.flat_map(fn(row) {
      range(target.grid_w)
      |> list.map(fn(col) {
        render_cell(target, col, row, fg_hex, color_to_hex(target.bg))
      })
    })
    |> string.join("\n")

  string.join(
    [
      "<svg xmlns=\"http://www.w3.org/2000/svg\"",
      "  width=\"" <> size_str <> "\" height=\"" <> size_str <> "\"",
      "  shape-rendering=\"crispEdges\"",
      "  viewBox=\"0 0 " <> vb_w_str <> " " <> vb_h_str <> "\">",
      "  <rect width=\""
        <> vb_w_str
        <> "\" height=\""
        <> vb_h_str
        <> "\" fill=\""
        <> bg_hex
        <> "\"/>",
      cells,
      "</svg>",
    ],
    "\n",
  )
}

// ---------------------------------------------------------------------------
// Cell rendering
// ---------------------------------------------------------------------------

fn render_cell(
  target: RenderTarget,
  col: Int,
  row: Int,
  fg: String,
  bg: String,
) -> String {
  let x = col * 100
  let y = row * 100
  let tile = target.tile(col, row)

  case tile {
    Empty -> ""

    Solid ->
      "<rect x=\""
      <> int.to_string(x)
      <> "\" y=\""
      <> int.to_string(y)
      <> "\" width=\"100\" height=\"100\" fill=\""
      <> fg
      <> "\"/>"

    // Arc TL + Arc BR
    ArcDiagA ->
      arc_path(x, y, x, y, fg) <> "\n" <> arc_path(x, y, x + 100, y + 100, fg)

    // Arc TR + Arc BL
    ArcDiagB ->
      arc_path(x, y, x + 100, y, fg) <> "\n" <> arc_path(x, y, x, y + 100, fg)
  }
}

// ---------------------------------------------------------------------------
// Arc path (filled pie wedge from corner (cx,cy) to two adjacent midpoints)
// ---------------------------------------------------------------------------

fn arc_path(cell_x: Int, cell_y: Int, cx: Int, cy: Int, fg: String) -> String {
  let r = 50
  let #(p1x, p1y, p2x, p2y, sweep) = case cx - cell_x, cy - cell_y {
    // top-left: sweep clockwise (1)
    0, 0 -> #(cx + r, cy, cx, cy + r, 1)
    // top-right: sweep counterclockwise (0)
    _, 0 -> #(cx - r, cy, cx, cy + r, 0)
    // bottom-right: sweep counterclockwise (0) 
    a, b if a > 0 && b > 0 -> #(cx - r, cy, cx, cy - r, 1)
    // bottom-left: sweep clockwise (1)
    _, _ -> #(cx + r, cy, cx, cy - r, 0)
  }

  "<path d=\"M "
  <> int.to_string(cx)
  <> " "
  <> int.to_string(cy)
  <> " L "
  <> int.to_string(p1x)
  <> " "
  <> int.to_string(p1y)
  <> " A "
  <> int.to_string(r)
  <> " "
  <> int.to_string(r)
  <> " 0 0 "
  <> int.to_string(sweep)
  <> " "
  <> int.to_string(p2x)
  <> " "
  <> int.to_string(p2y)
  <> " Z\" fill=\""
  <> fg
  <> "\"/>"
}

// ---------------------------------------------------------------------------
// Color helpers
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Range helper
// ---------------------------------------------------------------------------

fn range(n: Int) -> List(Int) {
  range_acc(0, n, [])
}

fn range_acc(i: Int, n: Int, acc: List(Int)) -> List(Int) {
  case i >= n {
    True -> list.reverse(acc)
    False -> range_acc(i + 1, n, [i, ..acc])
  }
}
