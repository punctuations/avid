import avid/avatar
import avid/render_bmp
import avid/render_png
import avid/render_svg
import avid/truchet

pub type Avatar =
  avatar.Avatar

pub type Truchet =
  truchet.Truchet

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
// Library API - Avatar
// ---------------------------------------------------------------------------

pub fn from_name(name: String) -> Avatar {
  avatar.from_name(name)
}

pub fn to_svg(av: Avatar, size: Int) -> String {
  render_svg.render(avatar.to_render_target(av), size)
}

pub fn to_bmp(av: Avatar, size: Int) -> BitArray {
  render_bmp.render(avatar.to_render_target(av), size)
}

pub fn to_png(av: Avatar, size: Int) -> BitArray {
  render_png.render(avatar.to_render_target(av), size)
}

// ---------------------------------------------------------------------------
// Library API - Truchet
// ---------------------------------------------------------------------------

pub fn truchet_from_name(name: String) -> Truchet {
  truchet.from_name(name)
}

pub fn truchet_to_svg(tr: Truchet, size: Int) -> String {
  render_svg.render(truchet.to_render_target(tr), size)
}

pub fn truchet_to_bmp(tr: Truchet, size: Int) -> BitArray {
  render_bmp.render(truchet.to_render_target(tr), size)
}

pub fn truchet_to_png(tr: Truchet, size: Int) -> BitArray {
  render_png.render(truchet.to_render_target(tr), size)
}
