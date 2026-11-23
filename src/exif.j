# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.27.0

/**
 * exif - read, modify and delete EXIF metadata in JPEG, PNG and WebP images.
 *
 *   images     {@link read} / {@link write} / {@link strip} / {@link hasExif} / {@link format}
 *   files      {@link readFile} / {@link writeFile} / {@link stripFile}
 *   payloads   {@link parse} / {@link render}
 *   entries    {@link get} / {@link set} / {@link remove} / {@link makeEntry}
 *   values     {@link text} / {@link ints} / {@link rationals} / {@link floats} / {@link raw}
 *   privacy    {@link removeGps} / {@link removeThumbnail}
 *   readers    {@link orientation} / {@link gps} / {@link dateTime} / {@link gpsTime}
 *
 * An {@link Exif} holds every entry of IFD0, the Exif, GPS and
 * Interoperability IFDs and IFD1, plus the thumbnail. Tags are named by a
 * string: `"Make"`, `"ifd1:XResolution"`, or `"gps:0x0002"` by number.
 * `write` re-serialises the whole structure and replaces only the EXIF
 * segment or chunk of the image.
 *
 * Value-semantic: a function that changes an `Exif` returns it, so the
 * calling shape is `$e = exif.setText($e, ...)`. Malformed data and misuse
 * throw {@link ExifError} (kind `"exif"`); a reached cap is kind `"limit"`.
 *
 * The topic files under `topics/` are spliced in with `include`; this file is
 * the module boundary. Tests: `exif_test.j`.
 *
 * @module exif
 * @see https://www.cipa.jp/std/documents/download_e.html?DC-008-Translation-2023-E
 * @example
 *   import "@deckyard/exif/" as exif;
 *
 *   def img as bytes init fs.readBytes("photo.jpg");
 *   def e as exif.Exif init exif.read($img);
 *   io.printf("%s %s\n", exif.text($e, "Make"), exif.text($e, "Model"));
 *   $e = exif.removeGps($e);
 *   fs.writeBytes("shared.jpg", exif.write($img, $e));
 */

use binary;
use convert;
use crc;
use encoding;
use fs;
use io;
use lists;
use maps;
use math;
use regex;
use strings;
use time;
use uuid;

include "topics/core.j";
include "topics/tags.j";
include "topics/model.j";
include "topics/tiff.j";
include "topics/image.j";
include "topics/jpeg.j";
include "topics/png.j";
include "topics/webp.j";
include "topics/readers.j";
