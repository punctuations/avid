/// BMP renderer for avatars.
///
/// Produces a 24-bit uncompressed BMP (DIB header format) as a BitArray.
///
/// BMP pixel rows are stored bottom-up and each row is padded to a
/// multiple of 4 bytes. For a 5-column-grid scaled to N pixels wide:
///   row_stride = ceil(width * 3 / 4) * 4
import avid/avatar.{type Avatar}
import gleam/bytes_tree.{type BytesTree}
import gleam/int
import gleam/list

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Render an Avatar as a 24-bit BMP BitArray.
///
/// `cell_size` is the pixel size of each grid cell (e.g. 40 -> 200x200 image).
pub fn render(av: Avatar, cell_size: Int) -> BitArray {
  let width = 5 * cell_size
  let height = 5 * cell_size

  // Row stride must be padded to 4 bytes
  let raw_stride = width * 3
  let padding = { 4 - raw_stride % 4 } % 4
  let stride = raw_stride + padding

  let pixel_data_size = stride * height
  let file_size = 54 + pixel_data_size

  let header = bmp_headers(width, height, file_size, pixel_data_size)
  let pixels = render_pixels(av, width, height, cell_size, padding)

  bytes_tree.to_bit_array(bytes_tree.append(header, pixels))
}

// ---------------------------------------------------------------------------
// BMP file header + DIB header (54 bytes total)
// ---------------------------------------------------------------------------

fn bmp_headers(
  width: Int,
  height: Int,
  file_size: Int,
  pixel_data_size: Int,
) -> BytesTree {
  bytes_tree.from_bit_array(<<
    // --- File header (14 bytes) ---
    0x42, 0x4D, file_size:32-little, 0:16, 0:16, 54:32-little,
    // --- DIB / BITMAPINFOHEADER (40 bytes) ---
    40:32-little, width:32-little, -height:32-little, 1:16-little, 24:16-little,
    0:32-little, pixel_data_size:32-little, 2835:32-little, 2835:32-little,
    0:32-little, 0:32-little,
  >>)
}

// ---------------------------------------------------------------------------
// Pixel data
// ---------------------------------------------------------------------------

fn render_pixels(
  av: Avatar,
  width: Int,
  height: Int,
  cell_size: Int,
  padding: Int,
) -> BitArray {
  render_rows_loop(av, width, height, cell_size, padding, 0, <<>>)
}

fn render_rows_loop(
  av: Avatar,
  width: Int,
  height: Int,
  cell_size: Int,
  padding: Int,
  py: Int,
  acc: BitArray,
) -> BitArray {
  case py >= height {
    True -> acc
    False -> {
      let row = render_row(av, py, width, cell_size, padding)
      render_rows_loop(av, width, height, cell_size, padding, py + 1, <<
        acc:bits,
        row:bits,
      >>)
    }
  }
}

fn render_row(
  av: Avatar,
  py: Int,
  width: Int,
  cell_size: Int,
  padding: Int,
) -> BitArray {
  let grid_row = py / cell_size
  let pixels = render_pixels_loop(av, grid_row, width, cell_size, 0, <<>>)
  let pad = render_padding_loop(padding, <<>>)
  <<pixels:bits, pad:bits>>
}

fn render_pixels_loop(
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
      let cell_index = grid_row * 5 + grid_col
      let filled = get_cell(av.grid, cell_index)
      let color = case filled {
        True -> av.fg
        False -> av.bg
      }
      // BMP stores BGR, not RGB
      render_pixels_loop(av, grid_row, width, cell_size, px + 1, <<
        acc:bits,
        color.b,
        color.g,
        color.r,
      >>)
    }
  }
}

fn render_padding_loop(remaining: Int, acc: BitArray) -> BitArray {
  case remaining <= 0 {
    True -> acc
    False -> render_padding_loop(remaining - 1, <<acc:bits, 0>>)
  }
}

fn get_cell(grid: List(Bool), index: Int) -> Bool {
  case list.drop(grid, index) {
    [v, ..] -> v
    [] -> False
  }
}

// ---------------------------------------------------------------------------
// Utility
// ---------------------------------------------------------------------------

pub fn clamp_byte(n: Int) -> Int {
  int.clamp(n, 0, 255)
}
