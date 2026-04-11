/// Shared rendering protocol used by all renderers.
///
/// Both Avatar and Truchet convert to a RenderTarget which the
/// renderers (svg, png, bmp) consume.
import avid/color.{type Color}

// ---------------------------------------------------------------------------
// Tile type, used by SVG renderer to emit vector paths.
// Bitmap renderers use the pixel fn instead.
// ---------------------------------------------------------------------------

pub type TileVariant {
  /// Solid filled rectangle (avatar cells)
  Solid
  /// Arc from top-left corner + arc from bottom-right corner
  ArcDiagA
  /// Arc from top-right corner + arc from bottom-left corner
  ArcDiagB
  /// Empty cell
  Empty
}

// ---------------------------------------------------------------------------
// RenderTarget
// ---------------------------------------------------------------------------

pub type RenderTarget {
  RenderTarget(
    grid_w: Int,
    grid_h: Int,
    fg: Color,
    bg: Color,
    /// For SVG: returns the tile variant at (col, row)
    tile: fn(Int, Int) -> TileVariant,
    /// For PNG/BMP: returns True if pixel (local_x, local_y) in cell (col, row)
    /// should be foreground. cell_size is the pixel size of one cell.
    pixel: fn(Int, Int, Int, Int, Int) -> Bool,
  )
}
