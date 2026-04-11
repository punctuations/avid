/// Core avatar data and generation logic.
///
/// An Avatar is fully derived from a name string. The same name always
/// produces the same avatar. All rendering modules consume this type
/// via to_render_target.
import avid/render
import gleam/int
import gleam/list
import gleam/string

import avid/color.{type Color, Color}

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

pub type Avatar {
  Avatar(
    name: String,
    hash: Int,
    fg: Color,
    bg: Color,
    /// 5x5 boolean grid (true = filled). Mirrored left-right for symmetry.
    grid: List(Bool),
  )
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

pub fn from_name(name: String) -> Avatar {
  let hash = fnv1a(name)
  let fg = fg_color(hash)
  let bg = bg_color(hash)
  let grid = build_grid(hash)
  Avatar(name: name, hash: hash, fg: fg, bg: bg, grid: grid)
}

pub fn to_render_target(av: Avatar) -> render.RenderTarget {
  render.RenderTarget(
    grid_w: 5,
    grid_h: 5,
    fg: av.fg,
    bg: av.bg,
    tile: fn(col, row) {
      let idx = row * 5 + col
      case list.drop(av.grid, idx) {
        [True, ..] -> render.Solid
        _ -> render.Empty
      }
    },
    pixel: fn(cell_col, cell_row, _local_x, _local_y, _cell_size) {
      let idx = cell_row * 5 + cell_col
      case list.drop(av.grid, idx) {
        [v, ..] -> v
        [] -> False
      }
    },
  )
}

// ---------------------------------------------------------------------------
// Hash
// ---------------------------------------------------------------------------

fn fnv1a(input: String) -> Int {
  let codepoints = string.to_utf_codepoints(input)
  list.fold(codepoints, 2_166_136_261, fn(hash, cp) {
    let byte = string.utf_codepoint_to_int(cp)
    let xored = int.bitwise_exclusive_or(hash, byte)
    int.bitwise_and(xored * 16_777_619, 0xFFFF_FFFF)
  })
}

// ---------------------------------------------------------------------------
// Color derivation
// ---------------------------------------------------------------------------

fn fg_color(hash: Int) -> Color {
  let hue = int.bitwise_and(hash, 0xFF) * 360 / 255
  let l_index = int.bitwise_and(int.bitwise_shift_right(hash, 8), 0x3)
  let lightness = 45 + l_index * 5
  hsl_to_rgb(hue, 65, lightness)
}

fn bg_color(hash: Int) -> Color {
  let hue = int.bitwise_and(hash, 0xFF) * 360 / 255
  hsl_to_rgb(hue, 30, 93)
}

pub fn hsl_to_rgb(h: Int, s: Int, l: Int) -> Color {
  let s1 = s * 10
  let l1 = l * 10
  let c = { 1000 - int.absolute_value(2 * l1 - 1000) } * s1 / 1000
  let h6 = h * 10 / 600
  let h_mod = h * 10 - h6 * 600
  let x = case int.bitwise_and(h6, 1) {
    0 -> c * h_mod / 600
    _ -> c * { 600 - h_mod } / 600
  }
  let m = l1 - c / 2
  let #(r1, g1, b1) = case h6 {
    0 -> #(c, x, 0)
    1 -> #(x, c, 0)
    2 -> #(0, c, x)
    3 -> #(0, x, c)
    4 -> #(x, 0, c)
    _ -> #(c, 0, x)
  }
  Color(
    r: { r1 + m } * 255 / 1000,
    g: { g1 + m } * 255 / 1000,
    b: { b1 + m } * 255 / 1000,
  )
}

// ---------------------------------------------------------------------------
// Grid generation
// ---------------------------------------------------------------------------

fn build_grid(hash: Int) -> List(Bool) {
  [0, 1, 2, 3, 4]
  |> list.flat_map(fn(row) {
    let shifted = int.bitwise_shift_right(hash, row * 3)
    let b0 = int.bitwise_and(shifted, 0x1) == 1
    let b1 = int.bitwise_and(shifted, 0x2) == 2
    let b2 = int.bitwise_and(shifted, 0x4) == 4
    [b0, b1, b2, b1, b0]
  })
}
