import avid/avatar
import avid/render_bmp
import avid/render_png
import avid/render_svg
import gleam/erlang/process
import gleam/int
import mist
import server/router
import wisp
import wisp/wisp_mist

pub type Avatar =
  avatar.Avatar

// ---------------------------------------------------------------------------
// Server entrypoint (gleam run)
// ---------------------------------------------------------------------------

pub fn main() {
  wisp.configure_logger()

  let port = 3000
  let assert Ok(_) =
    wisp_mist.handler(router.handle, "")
    |> mist.new()
    |> mist.port(port)
    |> mist.start()

  wisp.log_info("listening on http://localhost:" <> int.to_string(port))
  process.sleep_forever()
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
