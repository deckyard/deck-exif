# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.28.0

/**
 * White-box tests for the exif module: jennifer test src/exif_test.j
 *
 * One test file per topic under `topics/`, spliced with `include` in the
 * order `exif.j` uses. The fixtures (small WebP files as base64, JPEG and
 * PNG made with `images`, and a TIFF builder independent of the writer) live
 * in `topics/fixtures/images_test.j`, included by `core_test.j`, so the
 * suite runs from a copy of `src/` alone.
 */

use testing;
use images;
use path;

include "topics/core_test.j";
include "topics/tags_test.j";
include "topics/model_test.j";
include "topics/tiff_test.j";
include "topics/image_test.j";
include "topics/jpeg_test.j";
include "topics/png_test.j";
include "topics/webp_test.j";
include "topics/readers_test.j";
