#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.28.0

/**
 * Print every EXIF tag of an image: jennifer run examples/tags.j photo.jpg
 *
 * Without an argument it tags a small PNG in memory first, so it runs
 * anywhere (CI runs every example this way).
 */

use io;
use os;
use fs;
use images;
use time;

import "../src/exif.j" as exif;

def img as bytes;
if (len(os.ARGS) > 1) {
    $img = fs.readBytes(os.ARGS[1]);
} else {
    def demo as exif.Exif init exif.empty("le");
    $demo = exif.setText($demo, "Make", "Jennifer");
    $demo = exif.setText($demo, "Model", "Example Camera");
    $demo = exif.setInts($demo, "Orientation", [1]);
    $demo = exif.setText($demo, "DateTimeOriginal", "2026:11:23 10:30:00");
    $demo = exif.setText($demo, "OffsetTimeOriginal", "+01:00");
    $demo = exif.setRationals($demo, "ExposureTime", [exif.Rational{num: 1, den: 250}]);
    $demo = exif.setRationals($demo, "FNumber", [exif.Rational{num: 28, den: 10}]);
    $demo = exif.setGps($demo, 48.2082, 16.3738);
    $img = exif.write(images.encode("png", images.create(8, 8)), $demo);
}

io.printf("%s image\n", exif.format($img));
def e as exif.Exif init exif.read($img);
if (len($e.entries) == 0) {
    io.printf("no EXIF\n");
    exit;
}

for (def entry in $e.entries) {
    def name as string init exif.tagName($entry.ifd, $entry.tag);
    if ($name == "") {
        $name = io.sprintf("0x%d|base=16|pad=4|fill=0", $entry.tag);
    }
    io.printf("%s|pad=8 %s|pad=28 %s\n", $entry.ifd, $name, exif.describe($entry));
}
if (len($e.thumbnail) > 0) {
    io.printf("thumbnail: %d bytes\n", len($e.thumbnail));
}

if (exif.has($e, "DateTimeOriginal")) {
    io.printf("taken:     %s\n", time.iso(exif.dateTime($e, "DateTimeOriginal", time.UTC)));
}
if (exif.hasGps($e)) {
    def g as exif.Gps init exif.gps($e);
    io.printf("location:  %f|prec=6, %f|prec=6\n", $g.latitude, $g.longitude);
}
