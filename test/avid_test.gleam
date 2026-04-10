import avid
import avid/avatar
import gleam/string
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

// ---------------------------------------------------------------------------
// Determinism
// ---------------------------------------------------------------------------

pub fn same_name_same_hash_test() {
  let a = avatar.from_name("Alice")
  let b = avatar.from_name("Alice")
  a.hash |> should.equal(b.hash)
}

pub fn different_names_different_hash_test() {
  let a = avatar.from_name("Alice")
  let b = avatar.from_name("Bob")
  a.hash |> should.not_equal(b.hash)
}

pub fn case_sensitive_test() {
  let a = avatar.from_name("alice")
  let b = avatar.from_name("Alice")
  a.hash |> should.not_equal(b.hash)
}

// ---------------------------------------------------------------------------
// Grid
// ---------------------------------------------------------------------------

pub fn grid_length_test() {
  let av = avatar.from_name("test")
  av.grid |> list_length |> should.equal(25)
}

pub fn grid_is_mirrored_test() {
  let av = avatar.from_name("mirror")
  // Each row of 5: [c0,c1,c2,c1,c0] - col 0 == col 4, col 1 == col 3
  check_mirror(av.grid, 0)
}

fn check_mirror(grid: List(Bool), row: Int) {
  case row {
    5 -> Nil
    _ -> {
      let offset = row * 5
      let c0 = list_at(grid, offset + 0)
      let c1 = list_at(grid, offset + 1)
      let c4 = list_at(grid, offset + 4)
      let c3 = list_at(grid, offset + 3)
      c0 |> should.equal(c4)
      c1 |> should.equal(c3)
      check_mirror(grid, row + 1)
    }
  }
}

// ---------------------------------------------------------------------------
// SVG render
// ---------------------------------------------------------------------------

pub fn svg_contains_svg_tag_test() {
  let av = avid.from_name("Alice")
  let svg = avid.to_svg(av, 200)
  svg |> string.contains("<svg") |> should.be_true()
}

pub fn svg_contains_size_test() {
  let av = avid.from_name("Alice")
  let svg = avid.to_svg(av, 200)
  svg |> string.contains("200") |> should.be_true()
}

pub fn svg_closes_tag_test() {
  let av = avid.from_name("Alice")
  let svg = avid.to_svg(av, 200)
  svg |> string.contains("</svg>") |> should.be_true()
}

// ---------------------------------------------------------------------------
// BMP render
// ---------------------------------------------------------------------------

pub fn bmp_magic_bytes_test() {
  let av = avid.from_name("Alice")
  let bmp = avid.to_bmp(av, 40)
  // First two bytes must be "BM" (0x42, 0x4D)
  case bmp {
    <<0x42, 0x4D, _rest:bits>> -> should.be_true(True)
    _ -> should.be_true(False)
  }
}

pub fn bmp_file_size_test() {
  let av = avid.from_name("Alice")
  // 200x200 px, 24bpp, stride=600 (already multiple of 4), + 54 byte header
  let bmp = avid.to_bmp(av, 40)
  let expected = 54 + 600 * 200
  bmp |> bit_array_byte_size |> should.equal(expected)
}

// ---------------------------------------------------------------------------
// PNG render
// ---------------------------------------------------------------------------

pub fn png_magic_bytes_test() {
  let av = avid.from_name("Alice")
  let png = avid.to_png(av, 40)
  case png {
    <<137, 80, 78, 71, 13, 10, 26, 10, _rest:bits>> -> should.be_true(True)
    _ -> should.be_true(False)
  }
}

pub fn png_ends_with_iend_test() {
  let av = avid.from_name("Alice")
  let png = avid.to_png(av, 40)
  // IEND chunk: 00 00 00 00 "IEND" CRC(AE 42 60 82)
  let size = bit_array_byte_size(png)
  let tail = bit_array_slice(png, size - 12, 12)
  case tail {
    <<0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130>> -> should.be_true(True)
    _ -> should.be_true(False)
  }
}

// ---------------------------------------------------------------------------
// Color (HSL -> RGB sanity checks)
// ---------------------------------------------------------------------------

pub fn red_hsl_test() {
  // Pure red: hue=0, sat=100%, light=50% → R=255 G=0 B=0
  let c = avatar.hsl_to_rgb(0, 100, 50)
  c.r |> should.equal(255)
  c.g |> should.equal(0)
  c.b |> should.equal(0)
}

pub fn green_hsl_test() {
  // Pure green: hue=120
  let c = avatar.hsl_to_rgb(120, 100, 50)
  c.r |> should.equal(0)
  c.g |> should.equal(255)
  c.b |> should.equal(0)
}

pub fn blue_hsl_test() {
  // Pure blue: hue=240
  let c = avatar.hsl_to_rgb(240, 100, 50)
  c.r |> should.equal(0)
  c.g |> should.equal(0)
  c.b |> should.equal(255)
}

pub fn white_hsl_test() {
  // White: light=100
  let c = avatar.hsl_to_rgb(0, 0, 100)
  c.r |> should.equal(255)
  c.g |> should.equal(255)
  c.b |> should.equal(255)
}

pub fn black_hsl_test() {
  // Black: light=0
  let c = avatar.hsl_to_rgb(0, 0, 0)
  c.r |> should.equal(0)
  c.g |> should.equal(0)
  c.b |> should.equal(0)
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

import gleam/list

fn list_length(l: List(a)) -> Int {
  list.length(l)
}

fn list_at(l: List(a), index: Int) -> a {
  let assert [v, ..] = list.drop(l, index)
  v
}

fn bit_array_byte_size(bits: BitArray) -> Int {
  ba_size_loop(bits, 0)
}

fn ba_size_loop(bits: BitArray, acc: Int) -> Int {
  case bits {
    <<_, rest:bits>> -> ba_size_loop(rest, acc + 1)
    _ -> acc
  }
}

fn bit_array_slice(data: BitArray, offset: Int, length: Int) -> BitArray {
  let #(_, after) = split_at(data, offset)
  let #(chunk, _) = split_at(after, length)
  chunk
}

fn split_at(data: BitArray, n: Int) -> #(BitArray, BitArray) {
  split_at_loop(data, n, <<>>)
}

fn split_at_loop(data: BitArray, n: Int, acc: BitArray) -> #(BitArray, BitArray) {
  case n, data {
    0, rest -> #(acc, rest)
    _, <<byte, rest:bits>> -> split_at_loop(rest, n - 1, <<acc:bits, byte>>)
    _, _ -> #(acc, <<>>)
  }
}
