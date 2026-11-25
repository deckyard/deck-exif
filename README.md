# @deckyard/exif

[![test](https://github.com/deckyard/deck-exif/actions/workflows/test.yml/badge.svg)](https://github.com/deckyard/deck-exif/actions/workflows/test.yml)
[![Documentation](https://img.shields.io/badge/docs-github%20pages-blue)](https://deckyard.github.io/deck-exif/)
[![release](https://img.shields.io/github/v/release/deckyard/deck-exif)](https://github.com/deckyard/deck-exif/releases/latest)

Read, change and remove the EXIF metadata of JPEG, PNG and WebP images from
a [Jennifer](https://jennifer-lang.dev/) program: every IFD, all twelve field
types, the thumbnail, GPS and date readers. Writing replaces only the EXIF
segment or chunk; every other byte of the image stays as it was.

**[Documentation](https://deckyard.github.io/deck-exif/)**

## Install

```sh
jvc add @deckyard/exif
```

This vendors the deck to `vendor/deckyard/exif/`. Without `jvc`, unpack the
`src/` subtree of a release archive (`deckyard-exif-<version>.tar.gz`) there.

## Usage

```jennifer
import "@deckyard/exif/" as exif;

def img as bytes init fs.readBytes("photo.jpg");
def e as exif.Exif init exif.read($img);
io.printf("%s %s\n", exif.text($e, "Make"), exif.text($e, "Model"));

$e = exif.removeGps($e);
$e = exif.setText($e, "Artist", "Ada Lovelace");
fs.writeBytes("shared.jpg", exif.write($img, $e));
```

## Requirements

Jennifer 0.28.0 or newer. Pure Jennifer: no network, no external programs;
only `readFile`, `writeFile` and `stripFile` touch the disk.

## Development

```sh
tools/check-all.sh                   # the full gate, as CI runs it
jennifer test src/exif_test.j        # the test overlay
tools/check-docs.sh                  # docs against the code
tools/pack.sh dist                   # build the release archive
```

## Trademarks

XMP™ is a trademark of Adobe Inc. Canon™ is a trademark of Canon Inc. Sony™
is a trademark of Sony Group Corporation or its affiliates. TIFF™, DNG™ and
other product and company names may be trademarks of their respective
owners. They are used only to identify the formats and cameras this deck
works with. This deck is an independent project, not affiliated with,
sponsored or endorsed by Adobe Inc. or any camera maker.

## Licence

LGPL-3.0-only, see [LICENSE](LICENSE). Copyright (C) 2026 mplx &lt;mplx@jennifer-lang.dev&gt;.

`tools/check-headers.sh` checks every source file's SPDX header against
`deck.toml`.
