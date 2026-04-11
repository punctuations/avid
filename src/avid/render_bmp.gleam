/// BMP renderer.
///
/// Consumes a RenderTarget, works for both Avatar and Truchet.
/// Produces a 24-bit uncompressed top-down BMP. Rows padded to 4 bytes.
/// Pixels stored as BGR.
import avid/render.{type RenderTarget}
import gleam/bytes_tree.{type BytesTree}
import gleam/int

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

pub fn render(target: RenderTarget, size: Int) -> BitArray {
  let cell_size = int.max(1, size / target.grid_w)
  let width = target.grid_w * cell_size
  let height = target.grid_h * cell_size

  let raw_stride = width * 3
  let padding = { 4 - raw_stride % 4 } % 4
  let pixel_data_size = { raw_stride + padding } * height
  let file_size = 54 + pixel_data_size

  let header = bmp_headers(width, height, file_size, pixel_data_size)
  let pixels = render_pixels(target, width, height, cell_size, padding)

  bytes_tree.to_bit_array(bytes_tree.append(header, pixels))
}

// ---------------------------------------------------------------------------
// BMP headers
// ---------------------------------------------------------------------------

fn bmp_headers(
  width: Int,
  height: Int,
  file_size: Int,
  pixel_data_size: Int,
) -> BytesTree {
  bytes_tree.from_bit_array(<<
    0x42, 0x4D, file_size:32-little, 0:16, 0:16, 54:32-little, 40:32-little,
    width:32-little, -height:32-little, 1:16-little, 24:16-little, 0:32-little,
    pixel_data_size:32-little, 2835:32-little, 2835:32-little, 0:32-little,
    0:32-little,
  >>)
}

// ---------------------------------------------------------------------------
// Pixel data
// ---------------------------------------------------------------------------

fn render_pixels(
  target: RenderTarget,
  width: Int,
  height: Int,
  cell_size: Int,
  padding: Int,
) -> BitArray {
  render_rows_loop(target, width, height, cell_size, padding, 0, <<>>)
}

fn render_rows_loop(
  target: RenderTarget,
  width: Int,
  height: Int,
  cell_size: Int,
  padding: Int,
  py: Int,
  acc: BitArray,
) -> BitArray {
  case py >= height {
    True -> acc
    False ->
      render_rows_loop(target, width, height, cell_size, padding, py + 1, <<
        acc:bits,
        render_row(target, py, width, cell_size, padding):bits,
      >>)
  }
}

fn render_row(
  target: RenderTarget,
  py: Int,
  width: Int,
  cell_size: Int,
  padding: Int,
) -> BitArray {
  <<
    render_row_loop(target, py, width, cell_size, 0, <<>>):bits,
    render_padding(padding):bits,
  >>
}

fn render_row_loop(
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
      render_row_loop(target, py, width, cell_size, px + 1, <<
        acc:bits, c.b, c.g, c.r,
      >>)
    }
  }
}

fn render_padding(n: Int) -> BitArray {
  case n {
    0 -> <<>>
    1 -> <<0>>
    2 -> <<0, 0>>
    _ -> <<0, 0, 0>>
  }
}
