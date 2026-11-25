# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.28.0

# exif - white-box tests for the png topic.
# Spliced into exif_test.j via include - run with:
#   jennifer test src/exif_test.j

func testPngChunkAfterIhdrWithItsCrc() {
    def out as bytes init write(fxPng(), fxExif());
    def seg as Segment init pngLocate($out);
    testing.assertEqual($seg.start, 8 + 25);
    testing.assertTrue(hasAt($out, $seg.start + 4, encoding.encode("utf-8", "eXIf")));
    def body as bytes init $out[$seg.start + 4..$seg.end - 4];
    testing.assertEqual($out[$seg.end - 4..$seg.end], crc.compute("crc32", $body));
    testing.assertEqual(images.width(images.decode($out)), 2);
}

func testPngRefusesABadCrc() {
    def out as bytes init write(fxPng(), fxExif());
    def seg as Segment init pngLocate($out);
    $out[$seg.end - 1] = $out[$seg.end - 1] ^ 0xFF;
    try {
        read($out);
        testing.assertTrue(false);
    } catch (e) {
        testing.assertEqual(fxCaught($e).offset, $seg.end - 4);
    }
}

func testPngRefusesTwoChunks() {
    def out as bytes init write(fxPng(), fxExif());
    def seg as Segment init pngLocate($out);
    def twice as bytes init binary.join([$out[0..$seg.end], $out[$seg.start..len($out)]]);
    testing.assertThrowsArgs("read", [$twice], "exif");
}

func testPngRefusesMalformedChunks() {
    def img as bytes init fxPng();
    testing.assertThrowsArgs("read", [$img[0..len($img) - 12]], "exif");
    testing.assertThrowsArgs("read", [$img[0..20]], "exif");
    def noIhdr as bytes init binary.concat($img[0..8], $img[33..len($img)]);
    testing.assertThrowsArgs("read", [$noIhdr], "exif");
    def huge as bytes init binary.join([$img[0..33], fxBytes([0x80, 0, 0, 0]), $img[37..len($img)]]);
    testing.assertThrowsArgs("read", [$huge], "exif");
}

func testPngKeepsBytesAfterIend() {
    def img as bytes init binary.concat(fxPng(), fxBytes([1, 2, 3]));
    def out as bytes init write($img, fxExif());
    testing.assertEqual($out[len($out) - 3..len($out)], fxBytes([1, 2, 3]));
    testing.assertEqual(strip($out), $img);
}
