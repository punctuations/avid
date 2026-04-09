/// PNG renderer for avatars.
///
/// Produces a valid PNG file as a BitArray.
///
/// PNG structure:
///   1. 8-byte magic signature
///   2. IHDR chunk  (image header)
///   3. IDAT chunk  (compressed image data — deflate/zlib)
///   4. IEND chunk  (end marker)
///
/// Compression: use "stored" deflate blocks (type 00), no actual
/// compression, but fully spec-compliant. The zlib wrapper + Adler-32
/// checksum are computed manually.
///
/// Each pixel row is prefixed with a filter byte (0x00 = None).
/// Pixels are 3 bytes each (RGB, 8 bits per channel).
import avid/avatar.{type Avatar}
import gleam/bytes_tree
import gleam/int
import gleam/list

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Render an Avatar as a PNG BitArray.
///
/// `cell_size` pixels per grid cell (e.g. 40 -> 200x200 image).
pub fn render(av: Avatar, cell_size: Int) -> BitArray {
  let width = 5 * cell_size
  let height = 5 * cell_size

  let raw_rows = build_raw_rows(av, width, height, cell_size)
  let idat_data = zlib_wrap(raw_rows)

  let png =
    bytes_tree.from_bit_array(png_signature())
    |> bytes_tree.append(ihdr_chunk(width, height))
    |> bytes_tree.append(idat_chunk(idat_data))
    |> bytes_tree.append(iend_chunk())

  bytes_tree.to_bit_array(png)
}

// ---------------------------------------------------------------------------
// PNG Signature
// ---------------------------------------------------------------------------

fn png_signature() -> BitArray {
  <<137, 80, 78, 71, 13, 10, 26, 10>>
}

// ---------------------------------------------------------------------------
// IHDR chunk
// ---------------------------------------------------------------------------

fn ihdr_chunk(width: Int, height: Int) -> BitArray {
  let data = <<
    width:32,
    height:32,
    8,
    // bit depth
    2,
    // color type: RGB truecolor
    0,
    // compression method
    0,
    // filter method
    0,
    // interlace method
  >>
  make_chunk(<<"IHDR":utf8>>, data)
}

// ---------------------------------------------------------------------------
// IDAT chunk (image data)
// ---------------------------------------------------------------------------

fn idat_chunk(data: BitArray) -> BitArray {
  make_chunk(<<"IDAT":utf8>>, data)
}

// ---------------------------------------------------------------------------
// IEND chunk
// ---------------------------------------------------------------------------

fn iend_chunk() -> BitArray {
  make_chunk(<<"IEND":utf8>>, <<>>)
}

// ---------------------------------------------------------------------------
// Chunk builder: length + type + data + CRC32
// ---------------------------------------------------------------------------

fn make_chunk(chunk_type: BitArray, data: BitArray) -> BitArray {
  let data_len = bit_array_byte_size(data)
  let crc_input = <<chunk_type:bits, data:bits>>
  let crc = crc32(crc_input)
  <<data_len:32, chunk_type:bits, data:bits, crc:32>>
}

// ---------------------------------------------------------------------------
// Raw pixel rows (with PNG filter byte prefix)
// ---------------------------------------------------------------------------

fn build_raw_rows(
  av: Avatar,
  width: Int,
  height: Int,
  cell_size: Int,
) -> BitArray {
  build_rows_loop(av, width, height, cell_size, 0, <<>>)
}

fn build_rows_loop(
  av: Avatar,
  width: Int,
  height: Int,
  cell_size: Int,
  py: Int,
  acc: BitArray,
) -> BitArray {
  case py >= height {
    True -> acc
    False -> {
      let row = build_row(av, py, width, cell_size)
      build_rows_loop(
        av,
        width,
        height,
        cell_size,
        py + 1,
        <<acc:bits, 0, row:bits>>,
        // 0x00 = filter type None
      )
    }
  }
}

fn build_row(av: Avatar, py: Int, width: Int, cell_size: Int) -> BitArray {
  let grid_row = py / cell_size
  build_row_loop(av, grid_row, width, cell_size, 0, <<>>)
}

fn build_row_loop(
  av: Avatar,
  grid_row: Int,
  width: Int,
  cell_size: Int,
  px: Int,
  acc: BitArray,
) -> BitArray {
  case px >= width {
    True -> acc
    False -> {
      let grid_col = px / cell_size
      let idx = grid_row * 5 + grid_col
      let filled = get_cell(av.grid, idx)
      let c = case filled {
        True -> av.fg
        False -> av.bg
      }
      build_row_loop(av, grid_row, width, cell_size, px + 1, <<
        acc:bits,
        c.r,
        c.g,
        c.b,
      >>)
    }
  }
}

fn get_cell(grid: List(Bool), index: Int) -> Bool {
  case list.drop(grid, index) {
    [v, ..] -> v
    [] -> False
  }
}

// ---------------------------------------------------------------------------
// zlib wrapper with stored (uncompressed) deflate blocks
// ---------------------------------------------------------------------------

fn zlib_wrap(data: BitArray) -> BitArray {
  let adler = adler32(data)
  let blocks = deflate_stored(data)
  <<0x78, 0x01, blocks:bits, adler:32>>
}

fn deflate_stored(data: BitArray) -> BitArray {
  deflate_stored_loop(data, <<>>)
}

fn deflate_stored_loop(remaining: BitArray, acc: BitArray) -> BitArray {
  let total = bit_array_byte_size(remaining)
  case total {
    0 -> acc
    _ -> {
      let chunk_size = int.min(total, 65_535)
      let is_last = chunk_size == total
      let bfinal = case is_last {
        True -> 1
        False -> 0
      }
      let len = chunk_size
      let nlen = int.bitwise_exclusive_or(len, 0xFFFF)
      let #(chunk, rest) = split_bits(remaining, chunk_size * 8)
      let block = <<bfinal, len:16-little, nlen:16-little, chunk:bits>>
      deflate_stored_loop(rest, <<acc:bits, block:bits>>)
    }
  }
}

// ---------------------------------------------------------------------------
// Adler-32 checksum
// ---------------------------------------------------------------------------

fn adler32(data: BitArray) -> Int {
  let #(s1, s2) = adler32_loop(data, 1, 0)
  int.bitwise_or(int.bitwise_shift_left(s2, 16), s1)
}

fn adler32_loop(data: BitArray, s1: Int, s2: Int) -> #(Int, Int) {
  case data {
    <<byte, rest:bits>> -> {
      let s1_ = { s1 + byte } % 65_521
      let s2_ = { s2 + s1_ } % 65_521
      adler32_loop(rest, s1_, s2_)
    }
    _ -> #(s1, s2)
  }
}

// ---------------------------------------------------------------------------
// CRC-32
// ---------------------------------------------------------------------------

fn crc32(data: BitArray) -> Int {
  let crc = crc32_loop(data, 0xFFFF_FFFF)
  int.bitwise_exclusive_or(crc, 0xFFFF_FFFF)
}

fn crc32_loop(data: BitArray, crc: Int) -> Int {
  case data {
    <<byte, rest:bits>> -> {
      let low8 = int.bitwise_and(int.bitwise_exclusive_or(crc, byte), 0xFF)
      let shifted = int.bitwise_shift_right(crc, 8)
      let new_crc = int.bitwise_exclusive_or(shifted, crc32_table_entry(low8))
      crc32_loop(rest, new_crc)
    }
    _ -> crc
  }
}

fn crc32_table_entry(byte: Int) -> Int {
  crc32_bit_loop(byte, 8)
}

fn crc32_bit_loop(crc: Int, bits_left: Int) -> Int {
  case bits_left {
    0 -> crc
    _ -> {
      let bit = int.bitwise_and(crc, 1)
      let shifted = int.bitwise_shift_right(crc, 1)
      let next = case bit {
        0 -> shifted
        _ -> int.bitwise_exclusive_or(shifted, 0xEDB8_8320)
      }
      crc32_bit_loop(next, bits_left - 1)
    }
  }
}

// ---------------------------------------------------------------------------
// BitArray utilities
// ---------------------------------------------------------------------------

fn bit_array_byte_size(bits: BitArray) -> Int {
  ba_size_loop(bits, 0)
}

fn ba_size_loop(bits: BitArray, acc: Int) -> Int {
  case bits {
    <<_, rest:bits>> -> ba_size_loop(rest, acc + 1)
    _ -> acc
  }
}

fn split_bits(data: BitArray, bit_count: Int) -> #(BitArray, BitArray) {
  split_bits_loop(data, bit_count, <<>>)
}

fn split_bits_loop(
  data: BitArray,
  bits_left: Int,
  acc: BitArray,
) -> #(BitArray, BitArray) {
  case bits_left, data {
    0, rest -> #(acc, rest)
    _, <<byte, rest:bits>> ->
      split_bits_loop(rest, bits_left - 8, <<acc:bits, byte>>)
    _, _ -> #(acc, <<>>)
  }
}
