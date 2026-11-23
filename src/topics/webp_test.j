# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.27.0

# exif - white-box tests for the webp topic.
# Spliced into exif_test.j via include - run with:
#   jennifer test src/exif_test.j

# The VP8X flags byte and canvas of an extended WebP.
func fxVp8x(data as bytes) {
    testing.assertTrue(hasAt($data, 12, encoding.encode("utf-8", "VP8X")));
    return [
        $data[20],
        (binary.readUint("le", $data, 24, 4) & 0xFFFFFF) + 1,
        (binary.readUint("le", $data, 26, 4) >> 8) + 1
    ];
}

func testWebpSimpleBecomesExtended() {
    for (def b64 in [WEBP_LOSSY_BASE64, WEBP_LOSSLESS_BASE64]) {
        def img as bytes init fxB64($b64);
        def out as bytes init write($img, fxExif());
        testing.assertEqual(fxVp8x($out), [WEBP_EXIF_FLAG, 3, 2]);
        testing.assertEqual(binary.readUint("le", $out, 4, 4), len($out) - 8);
        testing.assertEqual($out[30..30 + len($img) - 12], $img[12..len($img)]);
        testing.assertEqual(read($out), fxExif());
    }
}

func testWebpLosslessAlphaSetsTheAlphaFlag() {
    def out as bytes init write(fxB64(WEBP_ALPHA_BASE64), fxExif());
    testing.assertEqual(fxVp8x($out), [WEBP_EXIF_FLAG | WEBP_ALPHA_FLAG, 3, 2]);
}

func testWebpStripClearsTheFlag() {
    def out as bytes init strip(write(fxWebp(), fxExif()));
    testing.assertEqual(fxVp8x($out), [0, 3, 2]);
    testing.assertFalse(hasExif($out));
    testing.assertEqual(binary.readUint("le", $out, 4, 4), len($out) - 8);
    testing.assertEqual(strip(fxWebp()), fxWebp());
}

func testWebpOddPayloadIsPadded() {
    # values are padded to even lengths; only an odd thumbnail makes the payload odd
    def x as Exif init setThumbnail(empty("le"), fxBytes([0xFF, 0xD8, 0xFF, 0xD9, 0]));
    def payload as bytes init render($x);
    testing.assertEqual(len($payload) % 2, 1);
    def out as bytes init write(fxWebp(), $x);
    testing.assertEqual(len($out) % 2, 0);
    testing.assertEqual(read($out), $x);
    def seg as Segment init webpLocate($out);
    testing.assertEqual($seg.end - $seg.payloadEnd, 1);
}

# An extended WebP with an XMP chunk and its flag.
func fxWebpWithXmp() {
    def ext as bytes init strip(write(fxWebp(), fxExif()));
    def xmp as bytes init binary.concat(encoding.encode("utf-8", "XMP "), fxUint("le", 4, 4));
    def out as bytes init binary.join([$ext, $xmp, encoding.encode("utf-8", "<x/>")]);
    $out[20] = $out[20] | 0x04;
    def size as bytes init fxUint("le", len($out) - 8, 4);
    for (def i in 0..4) {
        $out[4 + $i] = $size[$i];
    }
    return $out;
}

func testWebpExifGoesBeforeXmp() {
    def img as bytes init fxWebpWithXmp();
    def out as bytes init write($img, fxExif());
    def seg as Segment init webpLocate($out);
    testing.assertTrue(hasAt($out, $seg.end, encoding.encode("utf-8", "XMP ")));
    testing.assertEqual($out[20], 0x04 | WEBP_EXIF_FLAG);
    testing.assertEqual(strip($out), $img);
    # replaced in place on a second write
    def again as bytes init write($out, setText(fxExif(), "Artist", "B"));
    testing.assertEqual(webpLocate($again).start, $seg.start);
}

func testWebpRefuses() {
    def img as bytes init fxWebp();
    def out as bytes init write($img, fxExif());
    # RIFF size disagrees with the file
    testing.assertThrowsArgs("read", [binary.concat($out, fxBytes([0, 0]))], "exif");
    # flag without chunk, chunk without flag
    def flagOnly as bytes init strip($out);
    $flagOnly[20] = WEBP_EXIF_FLAG;
    testing.assertThrowsArgs("read", [$flagOnly], "exif");
    def chunkOnly as bytes init $out;
    $chunkOnly[20] = 0;
    testing.assertThrowsArgs("read", [$chunkOnly], "exif");
    # an EXIF chunk in a simple file
    def seg as Segment init webpLocate($out);
    def simple as bytes init binary.concat($img, $out[$seg.start..$seg.end]);
    def size as bytes init fxUint("le", len($simple) - 8, 4);
    for (def i in 0..4) {
        $simple[4 + $i] = $size[$i];
    }
    testing.assertThrowsArgs("read", [$simple], "exif");
    # two EXIF chunks
    def twice as bytes init binary.concat($out, $out[$seg.start..$seg.end]);
    $size = fxUint("le", len($twice) - 8, 4);
    for (def i in 0..4) {
        $twice[4 + $i] = $size[$i];
    }
    testing.assertThrowsArgs("read", [$twice], "exif");
    # an unknown first chunk, a chunk past the end
    def odd as bytes init $img;
    $odd[15] = 0x41;
    testing.assertThrowsArgs("read", [$odd], "exif");
    def cut2 as bytes init $img[0..len($img) - 4];
    $size = fxUint("le", len($cut2) - 8, 4);
    for (def i in 0..4) {
        $cut2[4 + $i] = $size[$i];
    }
    testing.assertThrowsArgs("read", [$cut2], "exif");
}

func testWebpRefusesAShortVp8x() {
    # VP8X of size 0: its flags byte would be the next chunk's first byte,
    # which write used to overwrite ("VP8 " became "^P8 ")
    def lossy as bytes init fxWebp();
    def img as bytes init binary.join([
        $lossy[0..12],
        encoding.encode("utf-8", "VP8X"),
        binary.make(4),
        $lossy[12..len($lossy)]
    ]);
    def size as bytes init fxUint("le", len($img) - 8, 4);
    for (def i in 0..4) {
        $img[4 + $i] = $size[$i];
    }
    testing.assertThrowsArgs("write", [$img, fxExif()], "exif");
    testing.assertThrowsArgs("read", [$img], "exif");
}

func testWebpRefusesABadBitstreamHeader() {
    def img as bytes init fxWebp();
    $img[23] = 0;
    testing.assertThrowsArgs("write", [$img, fxExif()], "exif");
    def lossless as bytes init fxB64(WEBP_LOSSLESS_BASE64);
    $lossless[20] = 0;
    testing.assertThrowsArgs("write", [$lossless, fxExif()], "exif");
}
