/// Shared Color type used by avatar, render, and renderers.
/// Lives in its own module to avoid import cycles.
pub type Color {
  Color(r: Int, g: Int, b: Int)
}
