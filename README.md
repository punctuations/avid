# avid

A deterministic avatar generator written in Gleam. Convert any name string into
a unique, symmetric, colorful avatar.

## How it works

```
Name string
    │
    V
FNV-1a 32-bit hash          (fast, good distribution, pure bitwise ops)
    │
    ├─> Hue from bits [7..0]  -> foreground + background color via HSL→RGB
    │
    └─> Bits [0..14]          -> 5×5 mirrored boolean grid
            │
            └─> Rendered to SVG / BMP / PNG
```

The 5x5 grid is mirrored left <-> right, giving it symmetry. Color is derived
from a hue extracted from the hash and converted through integer-only HSL -> RGB
math.

## Usage

```gleam
import avid

pub fn main() {
  let av = avid.from_name("John Doe")

  // SVG — pass pixel size for width/height attributes
  let svg: String = avid.to_svg(av, 200)

  // BMP — pass cell_size (pixels per grid cell); 40 → 200×200
  let bmp: BitArray = avid.to_bmp(av, 40)

  // PNG — same cell_size convention
  let png: BitArray = avid.to_png(av, 40)
}
```

## Running

```sh
gleam test    # run all tests
gleam build   # compile
```

## Implementation notes

### BMP format

The simplest possible image format. Header is 54 bytes (14-byte file header +
40-byte DIB header), followed by raw BGR pixel triplets. Rows are padded to
multiples of 4 bytes. Negative height value in the header means rows are stored
top-down.

### PNG format

A valid PNG with:

- `IHDR`: 8-bit RGB truecolor, no interlacing
- `IDAT`: zlib-wrapped (CMF=0x78, FLG=0x01), stored deflate blocks (BTYPE=00),
  Adler-32 checksum - no actual compression but fully spec-compliant
- `IEND`: end marker
- CRC-32 on each chunk computed with the IEEE 802.3 reflected polynomial

### Hash function

FNV-1a 32-bit. XOR-then-multiply per byte, masked to 32 bits. Offset basis:
2166136261, prime: 16777619.

### Color

HSL -> RGB using integer arithmetic only (scaled to x10 range). Hue is extracted
from bits [7..0] of the hash and scaled to 0–359. Saturation is fixed at 65% for
foreground (vivid) and 30% for background (muted). Lightness variants come from
bits [9..8].
