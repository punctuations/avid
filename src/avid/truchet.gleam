/// Core truchet tile data and generation logic.
///
/// Classic 2-variant Smith truchet tiles. Each cell in a 6x6 grid
/// gets one of two orientations determined deterministically from
/// the name hash.
///
/// Tile A: quarter-circle arc from top-left corner
///         + quarter-circle arc from bottom-right corner
/// Tile B: quarter-circle arc from top-right corner
///         + quarter-circle arc from bottom-left corner
import avid/color.{type Color, Color}
import avid/render
import gleam/int
import gleam/list
import gleam/string

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

pub type Orientation {
  /// Arc TL + arc BR
  DiagA
  /// Arc TR + arc BL
  DiagB
}

pub type Truchet {
  Truchet(
    name: String,
    hash: Int,
    /// 6x6 grid of tile orientations, row-major order (36 tiles)
    tiles: List(Orientation),
  )
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

pub const grid_size = 6

pub fn from_name(name: String) -> Truchet {
  let hash = fnv1a(name)
  let tiles = build_tiles(hash)
  Truchet(name: name, hash: hash, tiles: tiles)
}

pub fn to_render_target(tr: Truchet) -> render.RenderTarget {
  render.RenderTarget(
    grid_w: grid_size,
    grid_h: grid_size,
    fg: Color(r: 17, g: 17, b: 17),
    bg: Color(r: 245, g: 245, b: 245),
    tile: fn(col, row) {
      case get_tile(tr.tiles, row * grid_size + col) {
        DiagA -> render.ArcDiagA
        DiagB -> render.ArcDiagB
      }
    },
    pixel: fn(cell_col, cell_row, local_x, local_y, cell_size) {
      case get_tile(tr.tiles, cell_row * grid_size + cell_col) {
        DiagA -> pixel_diag_a(local_x, local_y, cell_size)
        DiagB -> pixel_diag_b(local_x, local_y, cell_size)
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
// Tile generation
// ---------------------------------------------------------------------------

fn build_tiles(hash: Int) -> List(Orientation) {
  range_loop(0, 35)
  |> list.map(fn(i) {
    let cell_hash = fnv1a_int(int.bitwise_exclusive_or(hash, i * 2_654_435_761))
    case int.bitwise_and(cell_hash, 1) {
      0 -> DiagA
      _ -> DiagB
    }
  })
}

fn fnv1a_int(n: Int) -> Int {
  let b0 = int.bitwise_and(n, 0xFF)
  let b1 = int.bitwise_and(int.bitwise_shift_right(n, 8), 0xFF)
  let b2 = int.bitwise_and(int.bitwise_shift_right(n, 16), 0xFF)
  let b3 = int.bitwise_and(int.bitwise_shift_right(n, 24), 0xFF)
  let h0 = 2_166_136_261
  let h1 =
    int.bitwise_and(int.bitwise_exclusive_or(h0, b0) * 16_777_619, 0xFFFF_FFFF)
  let h2 =
    int.bitwise_and(int.bitwise_exclusive_or(h1, b1) * 16_777_619, 0xFFFF_FFFF)
  let h3 =
    int.bitwise_and(int.bitwise_exclusive_or(h2, b2) * 16_777_619, 0xFFFF_FFFF)
  int.bitwise_and(int.bitwise_exclusive_or(h3, b3) * 16_777_619, 0xFFFF_FFFF)
}

fn get_tile(tiles: List(Orientation), idx: Int) -> Orientation {
  case list.drop(tiles, idx) {
    [t, ..] -> t
    [] -> DiagA
  }
}

// ---------------------------------------------------------------------------
// Pixel sampling, used by PNG and BMP renderers
//
// DiagA: two arcs centred at top-left (0,0) and bottom-right (S,S)
// DiagB: two arcs centred at top-right (S,0) and bottom-left (0,S)
//
// A pixel is filled if it falls within radius S/2 of either arc centre,
// but NOT within the corner circle (radius S/4) that stays background.
// ---------------------------------------------------------------------------

fn pixel_diag_a(px: Int, py: Int, s: Int) -> Bool {
  let r = s / 2
  let r2 = r * r
  dist2(px, py, 0, 0) <= r2 || dist2(px, py, s, s) <= r2
}

fn pixel_diag_b(px: Int, py: Int, s: Int) -> Bool {
  let r = s / 2
  let r2 = r * r
  dist2(px, py, s, 0) <= r2 || dist2(px, py, 0, s) <= r2
}

fn dist2(x1: Int, y1: Int, x2: Int, y2: Int) -> Int {
  let dx = x1 - x2
  let dy = y1 - y2
  dx * dx + dy * dy
}

// ---------------------------------------------------------------------------
// Range helper
// ---------------------------------------------------------------------------

fn range_loop(from: Int, to: Int) -> List(Int) {
  range_acc(from, to, [])
}

fn range_acc(i: Int, to: Int, acc: List(Int)) -> List(Int) {
  case i > to {
    True -> list.reverse(acc)
    False -> range_acc(i + 1, to, [i, ..acc])
  }
}
