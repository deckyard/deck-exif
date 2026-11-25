<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# Design

## Scope

Read, change and remove the EXIF metadata of JPEG, PNG and WebP images in
pure Jennifer, on `bytes`: no subprocess, no network, `fs` only in the
`...File` helpers.

- **Containers**: JPEG (an APP1 segment starting `Exif\0\0`), PNG (the
  `eXIf` chunk) and WebP (the `EXIF` chunk of the extended format, flagged
  in `VP8X`). The container is detected from the first bytes, never from a
  file name; anything else is an error.
- **The EXIF structure**: the TIFF™ header (`II` / `MM`, 42), IFD0, the Exif
  IFD (pointer tag `0x8769`), the GPS IFD (`0x8825`), the Interoperability
  IFD (`0xA005`, inside the Exif IFD) and IFD1 with its JPEG thumbnail. All
  twelve TIFF field types are read and written.

Not in scope:

- **TIFF-based raw files (DNG™, CR2, NEF, ...) and HEIC / AVIF.** In a raw file
  the EXIF structure *is* the image container, with strip and tile offsets
  pointing at pixel data; rewriting it is a different problem. HEIC keeps
  EXIF in an ISO-BMFF item whose location table would have to be rewritten.
- **XMP™ and IPTC.** They live in their own segments and chunks (JPEG APP1
  with the XMP namespace, APP13; PNG `iTXt`; WebP `XMP `) and are left as
  they are, also by `strip`. A privacy tool must remove them separately.
- **Decoding MakerNotes.** Vendor data is opaque.
- **Multi-segment EXIF** (the FlashPix™ extension over several APP2
  segments) and EXIF in PNG text chunks (`zTXt` "Raw profile type exif",
  ImageMagick™'s older form): not read, not written.

## Decisions

- **Bytes in, bytes out.** `read(data)` and `write(data, exif)` work on
  the whole image; `parse` and `render` on the bare TIFF payload. The image
  is passed read-only through every helper, so it is never copied while it
  is parsed; only the values themselves are sliced out.
- **Replace only the EXIF segment.** `write` re-serialises the complete TIFF
  structure and swaps it in for the old segment or chunk; every other byte
  of the file is copied unchanged, pixel data included. Only what the
  container makes depend on it changes with it: the PNG chunk CRC, the
  RIFF size and the `VP8X` EXIF flag. A new segment goes where readers look
  first: in JPEG after `SOI` and any `APP0` (JFIF), in PNG after `IHDR`, in
  WebP before `XMP ` or at the end.
- **A simple-format WebP is extended on write.** A `VP8 ` or `VP8L` file has
  no room for metadata, so `write` puts a `VP8X` chunk in front, with the
  canvas size read from the bitstream header and the alpha flag from the
  `VP8L` header. `strip` leaves a `VP8X` file extended, with the flag
  cleared.
- **The model is a flat list of entries.** `Exif` holds the byte order,
  every `Entry` (IFD name, tag, field type, count, value) and the thumbnail
  bytes. The structural tags (the three IFD pointers and the thumbnail's
  offset and length) are not entries: the writer recomputes them, so a
  caller can neither forget nor corrupt them. Unknown tags stay as entries
  and are written back unchanged.
- **One `Value` enum for twelve field types.** `Ints` holds `BYTE`,
  `SHORT`, `LONG`, `SBYTE`, `SSHORT` and `SLONG`; `Ascii` and `Undefined`
  hold raw bytes; `Rationals` both rational types; `Floats` `FLOAT` and
  `DOUBLE`. The entry's `type` says which exactly, and the writer checks the
  value fits it (range, variant). ASCII stays bytes because cameras write
  Latin-1 and UTF-8 into fields the standard calls 7-bit; `text` decodes
  UTF-8 on demand and refuses anything else, so one odd field does not make
  the whole image unreadable.
- **Tags are named by a string.** `"Make"`, `"GPSLatitude"`,
  `"ifd1:XResolution"`, or `"exif:0xA432"` / `"gps:5"` for any tag by
  number. A bare name finds its IFD in the table (TIFF tags default to
  IFD0); the `ifd:` prefix picks IFD1 or a tag outside the table. Numbers
  are not unique across IFDs (GPS tag 1 is `GPSLatitudeRef`, Interop tag 1
  `InteroperabilityIndex`), so a number always needs its IFD.
- **The table knows each tag's type**, so `setText`, `setInts`,
  `setRationals` and `setRaw` pick it (`SHORT` or `LONG` by value where the
  standard allows both). A tag outside the table is set through `makeEntry`
  with an explicit type.
- **The writer's layout**: header, then per IFD (0, Exif, Interop, GPS, 1)
  the entry table sorted by tag and its out-of-line values, each padded to
  an even length so every IFD and value starts on a word boundary, the
  thumbnail last. An IFD is written only when it has entries (the Exif IFD
  also when only the Interop IFD has).
- **One canonical entry order.** `read` lists entries by IFD (0, Exif,
  Interop, GPS, 1) and tag, and `set` inserts there, so `read(write(img,
  e)) == e` for any `e` built with the setters.
- **MakerNote is kept byte for byte but may move.** Many vendors store
  offsets in it relative to the TIFF header (Canon™, older Olympus™, Sony™);
  after a rewrite those point at the wrong bytes, and vendor tools can no
  longer read the MakerNote. Keeping it at its old offset would constrain
  the whole layout around one opaque block, for a guarantee the writer
  still could not give (the block can overlap anything). The deck keeps the
  data and documents the risk; `remove($e, "MakerNote")` drops it.
- **Uncompressed thumbnails are read, not rewritten.** `StripOffsets` and
  `TileOffsets` point at data the writer would not carry over; `write`
  refuses an `Exif` that holds one, and `removeThumbnail` clears IFD1.
- **Privacy helpers**: `removeGps` (the GPS IFD) and `removeThumbnail` (IFD1
  and its JPEG; the preview keeps the original picture after a crop). Both
  are one call because both are what people strip by hand. Serial numbers,
  owner names and MakerNotes are single `remove` calls; `strip` removes
  everything.
- **Readers for the common questions**: `orientation`, `gps` (decimal
  degrees and altitude), `gpsTime` (UTC by definition), `dateTime` (the
  `OffsetTime*` tag when the image has one, else the zone the caller passes:
  the deck never guesses a camera's zone), `setGps`.
- **Integer writing in one place.** `binary` has readers but no writers yet
  (roadmap M29.54); `uintBytes` in `core.j` shifts and masks, and is the one
  function to switch to the builtin. Floats are encoded by `floatBits`
  (IEEE 754, round half to even) for the same reason.
- **Files are replaced atomically.** `writeFile` and `stripFile` write a
  temporary file beside the target and rename it over, so a crash never
  leaves half an image. A symlinked target becomes a regular file, and the
  file gets the default mode of a new file rather than the old one's.
- **No EXIF is an empty `Exif`, not an error.** `read` of an image without
  EXIF returns `empty("be")`, ready for the setters and `write`; `hasExif`
  tells the two cases apart.

## Errors

Malformed data throws `ExifError` (`kind` `"exif"`, `message` starting
`exif: `, `offset` the byte offset in the input where the problem is, `-1`
when there is none). Every throw of kind `"exif"` is that struct. Misuse
(an unknown tag name, a value that does not fit its type, setting a
structural tag) is also kind `"exif"`, with `offset` `-1`.

A reached cap is a plain `Error` with kind `"limit"`. `fs` errors from the
file helpers pass through unchanged.

What is refused, rather than guessed:

- an unknown container, a truncated segment, chunk or IFD, a bad TIFF
  header, an offset or value past the end of the payload;
- an IFD offset seen before (a loop), a third IFD in the main chain, a
  sub-IFD with a next-IFD offset, a pointer tag in the wrong IFD;
- a field type outside 1-12, a tag twice in one IFD;
- two EXIF segments or chunks in one image, a PNG `eXIf` with a wrong CRC,
  a WebP `EXIF` chunk without the `VP8X` flag (or the flag without a chunk),
  an `EXIF` chunk in a simple-format WebP, a RIFF size that does not match
  the file;
- a payload too large for its container (a JPEG APP1 segment holds at most
  65,527 bytes of EXIF).

Not refused: entries out of tag order (TIFF says they must be sorted; the
order carries no meaning and the writer sorts), ASCII without a terminating
NUL, bytes after a PNG's `IEND` (copied unchanged).

## Security and limits

| Cap | Default (`Options` field) | Reached |
|---|---|---|
| EXIF payload size | 16 MiB (`maxBytes`) | `"limit"` |
| entries in one IFD | 1,000 (`maxEntries`) | `"limit"` |
| bytes of one value (`count` x type size), and the thumbnail | 1 MiB (`maxValueBytes`) | `"limit"` |
| bytes all values decode to | the payload cap (`maxBytes`) | `"limit"` |
| numbers all values decode to (integers, rational parts, floats) | 65,536, fixed | `"limit"` |

`readWith` and `parseWith` take `Options`; a zero field keeps the default,
a negative one or one above the default is an `"exif"` error (the caps only
go down). The IFD structure itself is bounded: at most five IFDs (IFD0,
IFD1, Exif, GPS, Interop), nesting at most two deep, and every IFD offset
is checked against those already read, so a crafted loop is an error, not a
hang. The value cap is checked before the value is bounds-checked, so a
huge `count` is `"limit"` even when it also runs past the end.

The two totals bound memory where the payload cap does not: values may all
point at the same bytes, so a 1 MiB payload could otherwise decode to
gigabytes, and a decoded number costs hundreds of bytes (a 1 MiB `BYTE`
value took 2 GB). Real images keep their numeric values small; long data is
`UNDEFINED`. `render`, and with it `write`, refuses metadata over any
default cap with `"limit"`, so the deck never writes what it cannot read.

## Testing and validation

- Fixtures are built in memory: JPEG and PNG from `images.encode`, WebP from
  two small base64 files made by ImageMagick (`src/topics/fixtures/`), EXIF
  payloads from hand-assembled IFDs in both byte orders. There is no
  `testdata/`, so the overlays run from a copy of `src/` alone.
- Covered: both byte orders, all twelve types inline and out of line, all
  five IFDs, the thumbnail, round trips (read, write, read equal), set and
  remove, strip, PNG CRCs, the WebP flag and simple-to-extended conversion,
  and every refusal above.
- Cross-checked by hand with ImageMagick 7.1.2 (`identify -format
  '%[EXIF:*]'`): an `Exif` with tags in all five IFDs, a thumbnail and
  every field type, written into JPEG, PNG, lossy and lossless WebP in both
  byte orders, reads the same in all eight files and as written; the
  stripped files show no EXIF and the same dimensions. ImageMagick prints
  `FLOAT` and `DOUBLE` as the integer of their first four bytes and repeats
  the first value of a multi-value rational outside the GPS IFD; the bytes
  were checked against Python's `struct` instead. ImageMagick is not
  available in CI, so this is not part of the gate.

## Known limitations and open questions

- MakerNote offsets (above). A future option could keep the MakerNote at its
  old offset when the layout allows it.
- A JPEG whose EXIF needs more than one APP1 segment cannot be written.
- `strip` removes EXIF only, not XMP, IPTC or ICC profiles.
- Text is written as UTF-8 although the standard asks for 7-bit ASCII;
  readers that insist on ASCII show the bytes.
- PNG `eXIf` is placed after `IHDR`; PNG editors that only look before
  `IDAT` find it, ones that expect it elsewhere were not seen.

## Dependencies on the interpreter

Floor `>=0.28.0` (the calls 0.29.0 removes are replaced by their 0.28.0 forms): `binary.readUint` / `readInts` / `readFloats` /
`indexOf`, `crc`, thrown structs keeping their identity. Runs on the default
binary; `jennifer-tiny` is not declared.
