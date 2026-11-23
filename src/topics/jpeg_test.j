# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.27.0

# exif - white-box tests for the jpeg topic.
# Spliced into exif_test.j via include - run with:
#   jennifer test src/exif_test.j

# A JPEG with a JFIF APP0 segment after SOI.
func fxJfif() {
    def img as bytes init fxJpeg();
    def app0 as bytes init fxBytes([
        0xFF,
        0xE0,
        0,
        16,
        0x4A,
        0x46,
        0x49,
        0x46,
        0,
        1,
        1,
        0,
        0,
        1,
        0,
        1,
        0,
        0
    ]);
    return binary.join([$img[0..2], $app0, $img[2..len($img)]]);
}

func testJpegGoesAfterApp0() {
    def img as bytes init fxJfif();
    def out as bytes init write($img, fxExif());
    testing.assertEqual($out[0..20], $img[0..20]);
    testing.assertEqual($out[20..22], fxBytes([0xFF, 0xE1]));
    def seg as Segment init jpegLocate($out);
    testing.assertEqual($seg.start, 20);
    testing.assertEqual($seg.payload, 30);
    testing.assertEqual(read($out), fxExif());
}

func testJpegReplacesInPlace() {
    def img as bytes init fxJfif();
    def first as bytes init write($img, fxExif());
    def second as bytes init write($first, setText(fxExif(), "Software", "a longer software name"));
    def seg as Segment init jpegLocate($second);
    testing.assertEqual($seg.start, 20);
    testing.assertEqual($second[$seg.end..len($second)], $img[20..len($img)]);
}

func testJpegSkipsOtherApp1AndFillBytes() {
    def img as bytes init fxJpeg();
    def xmp as bytes init binary.concat(
        fxBytes([0xFF, 0xFF, 0xFF, 0xE1, 0, 6]),
        encoding.encode("utf-8", "http"));
    def withXmp as bytes init binary.join([$img[0..2], $xmp, $img[2..len($img)]]);
    testing.assertFalse(hasExif($withXmp));
    def out as bytes init write($withXmp, fxExif());
    testing.assertEqual(read($out), fxExif());
    testing.assertEqual(strip($out), $withXmp);
}

func testJpegRefusesTwoExifSegments() {
    def out as bytes init write(fxJpeg(), fxExif());
    def seg as Segment init jpegLocate($out);
    def twice as bytes init binary.join([$out[0..$seg.end], $out[$seg.start..len($out)]]);
    testing.assertThrowsArgs("read", [$twice], "exif");
}

func testJpegRefusesMalformedHeaders() {
    def img as bytes init fxJpeg();
    testing.assertThrowsArgs("read", [$img[0..3]], "exif");
    testing.assertThrowsArgs("read", [$img[0..10]], "exif");
    def noMarker as bytes init binary.join([$img[0..2], fxBytes([0x12, 0x34]), $img[2..len($img)]]);
    testing.assertThrowsArgs("read", [$noMarker], "exif");
    def rst as bytes init binary.join([$img[0..2], fxBytes([0xFF, 0xD0]), $img[2..len($img)]]);
    testing.assertThrowsArgs("read", [$rst], "exif");
    def short as bytes init binary.join([
        $img[0..2],
        fxBytes([0xFF, 0xE2, 0, 1]),
        $img[2..len($img)]
    ]);
    testing.assertThrowsArgs("read", [$short], "exif");
}

func testJpegRefusesAnOversizedPayload() {
    def x as Exif init setRaw(fxExif(), "MakerNote", binary.make(JPEG_MAX_PAYLOAD));
    testing.assertThrowsArgs("write", [fxJpeg(), $x], "exif");
    # PNG and WebP have no such limit
    testing.assertEqual(read(write(fxPng(), $x)), $x);
}
