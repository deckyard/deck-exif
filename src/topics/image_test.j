# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.27.0

# exif - white-box tests for the image topic.
# Spliced into exif_test.j via include - run with:
#   jennifer test src/exif_test.j

# The three containers, each without EXIF.
func fxImages() {
    return [fxJpeg(), fxPng(), fxWebp()];
}

func testFormat() {
    testing.assertEqual(format(fxJpeg()), "jpeg");
    testing.assertEqual(format(fxPng()), "png");
    testing.assertEqual(format(fxWebp()), "webp");
    testing.assertThrowsArgs("format", [fxBytes([0x47, 0x49, 0x46, 0x38, 0x39, 0x61])], "exif");
    testing.assertThrowsArgs("format", [fxBytes([])], "exif");
    testing.assertThrowsArgs("format", [fxPayload("be", [])], "exif");
}

func testReadAnImageWithoutExif() {
    for (def img in fxImages()) {
        testing.assertFalse(hasExif($img));
        testing.assertEqual(read($img), empty("be"));
    }
}

func testWriteAndReadBackInEveryContainer() {
    for (def order in ["le", "be"]) {
        def x as Exif init setGps(fxExif(), -33.8568, 151.2153);
        $x.order = $order;
        $x = setThumbnail($x, fxJpeg());
        for (def img in fxImages()) {
            def out as bytes init write($img, $x);
            testing.assertTrue(hasExif($out));
            testing.assertEqual(read($out), $x);
            testing.assertEqual(format($out), format($img));
            # a second write replaces, it does not add
            def again as bytes init write($out, setText($x, "Artist", "Someone Else"));
            testing.assertEqual(text(read($again), "Artist"), "Someone Else");
            testing.assertEqual(
                len($again) - len($out),
                len(render(setText($x, "Artist", "Someone Else"))) - len(render($x)));
        }
    }
}

func testStripInEveryContainer() {
    for (def img in fxImages()) {
        def out as bytes init write($img, fxExif());
        def stripped as bytes init strip($out);
        testing.assertFalse(hasExif($stripped));
        testing.assertEqual(strip($stripped), $stripped);
    }
    # stripping puts JPEG and PNG back byte for byte
    testing.assertEqual(strip(write(fxJpeg(), fxExif())), fxJpeg());
    testing.assertEqual(strip(write(fxPng(), fxExif())), fxPng());
}

func testWriteKeepsEveryOtherByte() {
    def img as bytes init fxJpeg();
    def out as bytes init write($img, fxExif());
    def payload as bytes init render(fxExif());
    # SOI, the new segment (10 bytes of header), then the old image after SOI
    testing.assertEqual($out[0..2], $img[0..2]);
    testing.assertEqual($out[12..12 + len($payload)], $payload);
    testing.assertEqual($out[12 + len($payload)..len($out)], $img[2..len($img)]);
    testing.assertEqual(images.width(images.decode($out)), 4);
}

func testReadWithCaps() {
    def out as bytes init write(fxPng(), fxExif());
    testing.assertEqual(
        readWith($out, Options{maxBytes: 0, maxEntries: 0, maxValueBytes: 0}),
        fxExif());
    testing.assertThrowsArgs(
        "readWith",
        [$out, Options{maxBytes: 0, maxEntries: 1, maxValueBytes: 0}],
        "limit");
    testing.assertThrowsArgs(
        "readWith",
        [$out, Options{maxBytes: 0, maxEntries: -1, maxValueBytes: 0}],
        "exif");
    testing.assertThrowsArgs(
        "readWith",
        [fxPng(), Options{maxBytes: -1, maxEntries: 0, maxValueBytes: 0}],
        "exif");
}

func testReadReportsOffsetsInTheImage() {
    def out as bytes init write(fxJpeg(), fxExif());
    # break the TIFF magic: the error names its offset in the image
    $out[12 + 2] = 0;
    $out[12 + 3] = 0;
    try {
        read($out);
        testing.assertTrue(false);
    } catch (e) {
        testing.assertEqual(fxCaught($e).offset, 14);
    }
}

func testFiles() {
    def dir as string init fs.makeTempDir("", "exif-test");
    defer fs.removeAll($dir);
    def file as string init path.join($dir, "photo.jpg");
    fs.writeBytes($file, fxJpeg());
    writeFile($file, fxExif());
    testing.assertEqual(readFile($file), fxExif());
    stripFile($file);
    testing.assertEqual(fs.readBytes($file), fxJpeg());
    testing.assertEqual(fs.list($dir), ["photo.jpg"]);
    # a failed write leaves the file and no temporary behind
    fs.writeBytes($file, fxBytes([1, 2, 3]));
    testing.assertThrowsArgs("writeFile", [$file, fxExif()], "exif");
    testing.assertEqual(fs.list($dir), ["photo.jpg"]);
    try {
        readFile(path.join($dir, "missing.jpg"));
        testing.assertTrue(false);
    } catch (e) {
        # the fs error passes through, whatever its kind
        testing.assertNotEqual($e.kind, "exif");
    }
}

func testRemoveQuietly() {
    removeQuietly("/nonexistent/exif-test-file");
}
