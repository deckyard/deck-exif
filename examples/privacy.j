#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.27.0

/**
 * Prepare a photo for sharing: remove the location, the thumbnail (it keeps
 * the uncropped picture) and the serial numbers, keep the rest.
 *
 *   jennifer run examples/privacy.j photo.jpg shared.jpg
 *
 * Without arguments it works on a small JPEG made in memory and prints what
 * it removed, writing nothing.
 */

use io;
use os;
use fs;
use images;

import "../src/exif.j" as exif;

def img as bytes;
if (len(os.ARGS) > 2) {
    $img = fs.readBytes(os.ARGS[1]);
} else {
    def demo as exif.Exif init exif.setText(exif.empty("be"), "Model", "Example Camera");
    $demo = exif.setText($demo, "BodySerialNumber", "SN 0042");
    $demo = exif.setGps($demo, -33.8568, 151.2153);
    $demo = exif.setThumbnail($demo, images.encode("jpeg", images.create(4, 4)));
    $img = exif.write(images.encode("jpeg", images.create(64, 64)), $demo);
}

def before as exif.Exif init exif.read($img);
def after as exif.Exif init exif.removeThumbnail(exif.removeGps($before));
for (def tag in ["BodySerialNumber", "LensSerialNumber", "CameraOwnerName"]) {
    $after = exif.remove($after, $tag);
}
io.printf(
    "entries: %d -> %d, thumbnail: %d -> %d bytes\n",
    len($before.entries),
    len($after.entries),
    len($before.thumbnail),
    len($after.thumbnail));

def shared as bytes init exif.write($img, $after);
if (len(os.ARGS) > 2) {
    fs.writeBytes(os.ARGS[2], $shared);
    io.printf("wrote %s\n", os.ARGS[2]);
} else {
    io.printf("location left: %t\n", exif.hasGps(exif.read($shared)));
}
