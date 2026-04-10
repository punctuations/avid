import avid/avatar
import avid/render_bmp
import avid/render_png
import avid/render_svg

pub type Avatar =
  avatar.Avatar

// ---------------------------------------------------------------------------
// Server entrypoint (gleam run)
// ---------------------------------------------------------------------------

@target(javascript)
import server/router

@target(javascript)
pub fn main() {
  router.create_server(router.handle)
}

// ---------------------------------------------------------------------------
// Library API
// ---------------------------------------------------------------------------

pub fn from_name(name: String) -> Avatar {
  avatar.from_name(name)
}

pub fn to_svg(av: Avatar, size: Int) -> String {
  render_svg.render(av, size)
}

pub fn to_bmp(av: Avatar, cell_size: Int) -> BitArray {
  render_bmp.render(av, cell_size)
}

pub fn to_png(av: Avatar, cell_size: Int) -> BitArray {
  render_png.render(av, cell_size)
}
