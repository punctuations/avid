/// Core avatar data and generation logic.
///
/// An Avatar is fully derived from a name string. The same name always
/// produces the same avatar. All rendering modules consume this type.
import gleam/int
import gleam/list

// import gleam/option.{type Option, None, Some}
import gleam/string

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

pub type Color {
  Color(r: Int, g: Int, b: Int)
}

pub type Avatar {
  Avatar(
    /// Original input name
    name: String,
    /// 32-bit FNV-1a hash of the name
    hash: Int,
    /// Foreground cell color
    fg: Color,
    /// Background color
    bg: Color,
    /// 5x5 boolean grid (true = filled). Mirrored left-right for symmetry.
    grid: List(Bool),
  )
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Build an Avatar from a name string.
pub fn from_name(name: String) -> Avatar {
  let hash = fnv1a(name)
  let fg = fg_color(hash)
  let bg = bg_color(hash)
  let grid = build_grid(hash)
  Avatar(name: name, hash: hash, fg: fg, bg: bg, grid: grid)
}

// ---------------------------------------------------------------------------
// Hash
// ---------------------------------------------------------------------------

/// FNV-1a 32-bit hash. Deterministic, fast, good avalanche effect.
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

/// Foreground color: hue from bits [7..0], lightness variant from bits [9..8].
fn fg_color(hash: Int) -> Color {
  let hue = int.bitwise_and(hash, 0xFF) * 360 / 255
  let l_index = int.bitwise_and(int.bitwise_shift_right(hash, 8), 0x3)
  let lightness = 45 + l_index * 5
  hsl_to_rgb(hue, 65, lightness)
}

/// Background: very light tint of same hue from bits [7..0].
fn bg_color(hash: Int) -> Color {
  let hue = int.bitwise_and(hash, 0xFF) * 360 / 255
  hsl_to_rgb(hue, 30, 93)
}

/// HSL (h: 0-359, s: 0-100, l: 0-100) -> RGB (0-255 each).
/// Pure integer arithmetic — no floats.
pub fn hsl_to_rgb(h: Int, s: Int, l: Int) -> Color {
  let s1 = s * 10
  let l1 = l * 10
  let c = { 1000 - int.absolute_value(2 * l1 - 1000) } * s1 / 1000
  let h6 = h * 10 / 600
  let h_mod = h * 10 - h6 * 600
  let x = case int.bitwise_and(h6, 1) {
    0 -> c * h_mod / 600
    // even: rises 0..c
    _ -> c * { 600 - h_mod } / 600
    // odd: falls c..0
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

/// Build a 5x5 mirrored boolean grid from hash bits.
///
/// Rows 0-4, each row uses 3 bits from the hash to set the left half.
/// Columns are mirrored: [c0, c1, c2, c1, c0].
/// Returns a flat list of 25 bools in row-major order.
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
