/// PNG renderer.
///
/// Consumes a RenderTarget, works for both Avatar and Truchet.
/// Uses the pixel fn for rasterization.
import avid/render.{type RenderTarget}
import gleam/bit_array
import gleam/bytes_tree
import gleam/int

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

pub fn render(target: RenderTarget, size: Int) -> BitArray {
  let cell_size = int.max(1, size / target.grid_w)
  let width = target.grid_w * cell_size
  let height = target.grid_h * cell_size

  let raw_rows = build_raw_rows(target, width, height, cell_size)
  let idat_data = zlib_wrap(raw_rows)

  bytes_tree.to_bit_array(
    bytes_tree.from_bit_array(png_signature())
    |> bytes_tree.append(ihdr_chunk(width, height))
    |> bytes_tree.append(idat_chunk(idat_data))
    |> bytes_tree.append(iend_chunk()),
  )
}

// ---------------------------------------------------------------------------
// PNG structure
// ---------------------------------------------------------------------------

fn png_signature() -> BitArray {
  <<137, 80, 78, 71, 13, 10, 26, 10>>
}

fn ihdr_chunk(width: Int, height: Int) -> BitArray {
  make_chunk(<<"IHDR":utf8>>, <<width:32, height:32, 8, 2, 0, 0, 0>>)
}

fn idat_chunk(data: BitArray) -> BitArray {
  make_chunk(<<"IDAT":utf8>>, data)
}

fn iend_chunk() -> BitArray {
  make_chunk(<<"IEND":utf8>>, <<>>)
}

fn make_chunk(chunk_type: BitArray, data: BitArray) -> BitArray {
  let data_len = bit_array.byte_size(data)
  let crc = crc32(<<chunk_type:bits, data:bits>>)
  <<data_len:32, chunk_type:bits, data:bits, crc:32>>
}

// ---------------------------------------------------------------------------
// Pixel rows
// ---------------------------------------------------------------------------

fn build_raw_rows(
  target: RenderTarget,
  width: Int,
  height: Int,
  cell_size: Int,
) -> BitArray {
  build_rows_loop(target, width, height, cell_size, 0, <<>>)
}

fn build_rows_loop(
  target: RenderTarget,
  width: Int,
  height: Int,
  cell_size: Int,
  py: Int,
  acc: BitArray,
) -> BitArray {
  case py >= height {
    True -> acc
    False ->
      build_rows_loop(target, width, height, cell_size, py + 1, <<
        acc:bits,
        0,
        build_row(target, py, width, cell_size):bits,
      >>)
  }
}

fn build_row(
  target: RenderTarget,
  py: Int,
  width: Int,
  cell_size: Int,
) -> BitArray {
  build_row_loop(target, py, width, cell_size, 0, <<>>)
}

fn build_row_loop(
  target: RenderTarget,
  py: Int,
  width: Int,
  cell_size: Int,
  px: Int,
  acc: BitArray,
) -> BitArray {
  case px >= width {
    True -> acc
    False -> {
      let filled =
        target.pixel(
          px / cell_size,
          py / cell_size,
          px % cell_size,
          py % cell_size,
          cell_size,
        )
      let c = case filled {
        True -> target.fg
        False -> target.bg
      }
      build_row_loop(target, py, width, cell_size, px + 1, <<
        acc:bits,
        c.r,
        c.g,
        c.b,
      >>)
    }
  }
}

// ---------------------------------------------------------------------------
// zlib / deflate
// ---------------------------------------------------------------------------

fn zlib_wrap(data: BitArray) -> BitArray {
  <<0x78, 0x01, deflate_stored(data, <<>>):bits, adler32(data):32>>
}

fn deflate_stored(remaining: BitArray, acc: BitArray) -> BitArray {
  let total = bit_array.byte_size(remaining)
  case total {
    0 -> acc
    _ -> {
      let chunk_size = int.min(total, 65_535)
      let is_last = chunk_size == total
      let bfinal = case is_last {
        True -> 1
        False -> 0
      }
      let nlen = int.bitwise_exclusive_or(chunk_size, 0xFFFF)
      let #(chunk, rest) = slice(remaining, chunk_size)
      deflate_stored(rest, <<
        acc:bits,
        bfinal,
        chunk_size:16-little,
        nlen:16-little,
        chunk:bits,
      >>)
    }
  }
}

fn slice(data: BitArray, n: Int) -> #(BitArray, BitArray) {
  case bit_array.slice(data, 0, n) {
    Ok(chunk) -> {
      let rest_size = bit_array.byte_size(data) - n
      case bit_array.slice(data, n, rest_size) {
        Ok(rest) -> #(chunk, rest)
        Error(_) -> #(data, <<>>)
      }
    }
    Error(_) -> #(data, <<>>)
  }
}

fn adler32(data: BitArray) -> Int {
  let #(s1, s2) = adler32_loop(data, 1, 0)
  int.bitwise_or(int.bitwise_shift_left(s2, 16), s1)
}

fn adler32_loop(data: BitArray, s1: Int, s2: Int) -> #(Int, Int) {
  case data {
    <<byte, rest:bits>> -> {
      let s1_ = { s1 + byte } % 65_521
      adler32_loop(rest, s1_, { s2 + s1_ } % 65_521)
    }
    _ -> #(s1, s2)
  }
}

fn crc32(data: BitArray) -> Int {
  int.bitwise_exclusive_or(crc32_loop(data, 0xFFFF_FFFF), 0xFFFF_FFFF)
}

fn crc32_loop(data: BitArray, crc: Int) -> Int {
  case data {
    <<byte, rest:bits>> -> {
      let low8 = int.bitwise_and(int.bitwise_exclusive_or(crc, byte), 0xFF)
      let new_crc =
        int.bitwise_exclusive_or(
          int.bitwise_shift_right(crc, 8),
          crc32_table_entry(low8),
        )
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
      let next = case int.bitwise_and(crc, 1) {
        0 -> int.bitwise_shift_right(crc, 1)
        _ ->
          int.bitwise_exclusive_or(int.bitwise_shift_right(crc, 1), 0xEDB8_8320)
      }
      crc32_bit_loop(next, bits_left - 1)
    }
  }
}
