# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.27.0

# exif - white-box tests for the model topic.
# Spliced into exif_test.j via include - run with:
#   jennifer test src/exif_test.j

# An Exif with a few entries across IFDs.
func fxExif() {
    def x as Exif init empty("le");
    $x = setText($x, "Make", "Jennifer");
    $x = setText($x, "Model", "Deck One");
    $x = setInts($x, "Orientation", [6]);
    $x = setRationals($x, "ExposureTime", [Rational{num: 1, den: 125}]);
    $x = setInts($x, "PhotographicSensitivity", [400]);
    return $x;
}

func testEmpty() {
    def x as Exif init empty("be");
    testing.assertEqual($x.order, "be");
    testing.assertEqual(len($x.entries), 0);
    testing.assertEqual(len($x.thumbnail), 0);
    testing.assertThrowsArgs("empty", ["xx"], "exif");
}

func testMakeEntryFillsTheCount() {
    def e as Entry init makeEntry("exif:0xA460", TYPE_SHORT, Value.Ints{values: [1, 2, 3]});
    testing.assertEqual($e.ifd, IFD_EXIF);
    testing.assertEqual($e.tag, 0xA460);
    testing.assertEqual($e.count, 3);
    $e = makeEntry("UserComment", TYPE_UNDEFINED, Value.Undefined{data: fxBytes([1, 2])});
    testing.assertEqual($e.count, 2);
    $e = makeEntry("ifd0:0xC000", TYPE_DOUBLE, Value.Floats{values: [1.5]});
    testing.assertEqual($e.type, TYPE_DOUBLE);
}

func testMakeEntryChecksTheVariant() {
    def ints as Value init Value.Ints{values: [1]};
    testing.assertThrowsArgs("makeEntry", ["Make", TYPE_ASCII, $ints], "exif");
    testing.assertThrowsArgs("makeEntry", ["Make", TYPE_RATIONAL, $ints], "exif");
    testing.assertThrowsArgs("makeEntry", ["Make", 13, $ints], "exif");
    testing.assertThrowsArgs(
        "makeEntry",
        ["Make", TYPE_FLOAT, Value.Ascii{data: fxText("x")}],
        "exif");
    testing.assertThrowsArgs(
        "makeEntry",
        ["Make", TYPE_UNDEFINED, Value.Floats{values: [1.0]}],
        "exif");
}

func testMakeEntryChecksRanges() {
    def cases as list of list of int init [
        [1, 256],
        [1, -1],
        [3, 65536],
        [4, 4294967296],
        [4, -1],
        [6, 128],
        [6, -129],
        [8, 32768],
        [9, 2147483648],
        [9, -2147483649]
    ];
    for (def c in $cases) {
        testing.assertThrowsArgs(
            "makeEntry",
            ["ifd0:0xC000", $c[0], Value.Ints{values: [$c[1]]}],
            "exif");
    }
    def ok as list of list of int init [
        [1, 255],
        [3, 65535],
        [4, 4294967295],
        [6, -128],
        [8, -32768],
        [9, -2147483648]
    ];
    for (def c in $ok) {
        testing.assertEqual(makeEntry("ifd0:0xC000", $c[0], Value.Ints{values: [$c[1]]}).count, 1);
    }
    def big as Value init Value.Rationals{values: [Rational{num: 4294967296, den: 1}]};
    testing.assertThrowsArgs("makeEntry", ["ExposureTime", TYPE_RATIONAL, $big], "exif");
    def neg as Value init Value.Rationals{values: [Rational{num: -1, den: 3}]};
    testing.assertThrowsArgs("makeEntry", ["ExposureTime", TYPE_RATIONAL, $neg], "exif");
    testing.assertEqual(makeEntry("ExposureBiasValue", TYPE_SRATIONAL, $neg).count, 1);
}

func testMakeEntryRefusesStructuralTags() {
    def one as Value init Value.Ints{values: [8]};
    for (def tag in [
        "ifd0:0x8769",
        "ifd0:0x8825",
        "exif:0xA005",
        "ifd1:0x0201",
        "ifd1:0x0202",
        "gps:0x8769"
    ]) {
        testing.assertThrowsArgs("makeEntry", [$tag, TYPE_LONG, $one], "exif");
    }
    testing.assertThrowsArgs("makeEntry", ["ifd1:0x0111", TYPE_LONG, $one], "exif");
    testing.assertThrowsArgs("makeEntry", ["ifd0:0x0144", TYPE_LONG, $one], "exif");
}

func testCheckEntryRefusesAWrongCount() {
    def e as Entry init Entry{
        ifd: IFD0,
        tag: 0x0112,
        type: TYPE_SHORT,
        count: 2,
        value: Value.Ints{values: [1]}
    };
    testing.assertThrowsArgs("checkEntry", [$e], "exif");
    $e.count = 1;
    $e.ifd = "ifd7";
    testing.assertThrowsArgs("checkEntry", [$e], "exif");
    $e.ifd = IFD0;
    $e.tag = 70000;
    testing.assertThrowsArgs("checkEntry", [$e], "exif");
}

func testSetKeepsTheCanonicalOrder() {
    def x as Exif init fxExif();
    $x = setInts($x, "GPSAltitudeRef", [0]);
    $x = setText($x, "Artist", "Ada");
    $x = setInts($x, "ifd1:Compression", [6]);
    $x = setText($x, "InteroperabilityIndex", "R98");
    def got as list of string init [];
    for (def e in $x.entries) {
        $got[] = $e.ifd + ":" + hex4($e.tag);
    }
    testing.assertEqual(
        $got,
        [
            "ifd0:0x010F",
            "ifd0:0x0110",
            "ifd0:0x0112",
            "ifd0:0x013B",
            "exif:0x829A",
            "exif:0x8827",
            "interop:0x0001",
            "gps:0x0005",
            "ifd1:0x0103"
        ]);
}

func testSetReplaces() {
    def x as Exif init fxExif();
    def n as int init len($x.entries);
    $x = setText($x, "Make", "Other");
    testing.assertEqual(len($x.entries), $n);
    testing.assertEqual(text($x, "Make"), "Other");
    $x = set($x, makeEntry("Orientation", TYPE_LONG, Value.Ints{values: [3]}));
    testing.assertEqual(get($x, "Orientation").type, TYPE_LONG);
}

func testRemove() {
    def x as Exif init fxExif();
    testing.assertTrue(has($x, "Model"));
    $x = remove($x, "Model");
    testing.assertFalse(has($x, "Model"));
    def n as int init len($x.entries);
    $x = remove($x, "Model");
    testing.assertEqual(len($x.entries), $n);
    testing.assertThrowsArgs("remove", [$x, "NoSuchTag"], "exif");
}

func testGetAbsentThrows() {
    testing.assertThrowsArgs("get", [fxExif(), "Artist"], "exif");
}

func testSetTextAddsTheNul() {
    def x as Exif init setText(empty("be"), "Artist", "Zoë");
    def e as Entry init get($x, "Artist");
    testing.assertEqual($e.type, TYPE_ASCII);
    testing.assertEqual($e.count, 5);
    testing.assertEqual(raw($x, "Artist"), fxText("Zoë"));
    testing.assertEqual(text($x, "Artist"), "Zoë");
}

func testSetTextRefuses() {
    testing.assertThrowsArgs("setText", [empty("be"), "Artist", "a\0b"], "exif");
    testing.assertThrowsArgs("setText", [empty("be"), "Orientation", "1"], "exif");
    testing.assertThrowsArgs("setText", [empty("be"), "exif:0xA460", "x"], "exif");
}

func testSetIntsPicksShortOrLong() {
    def x as Exif init setInts(empty("be"), "PixelXDimension", [4000]);
    testing.assertEqual(get($x, "PixelXDimension").type, TYPE_SHORT);
    $x = setInts($x, "PixelXDimension", [70000]);
    testing.assertEqual(get($x, "PixelXDimension").type, TYPE_LONG);
    $x = setInts($x, "GPSVersionID", [2, 3, 0, 0]);
    testing.assertEqual(get($x, "GPSVersionID").type, TYPE_BYTE);
    testing.assertThrowsArgs("setInts", [$x, "Orientation", [70000]], "exif");
    testing.assertThrowsArgs("setInts", [$x, "Make", [1]], "exif");
}

func testSetRationalsAndRaw() {
    def x as Exif init setRationals(empty("le"), "ExposureBiasValue", [Rational{num: -1, den: 3}]);
    testing.assertEqual(get($x, "ExposureBiasValue").type, TYPE_SRATIONAL);
    testing.assertEqual(rationals($x, "ExposureBiasValue"), [Rational{num: -1, den: 3}]);
    $x = setRaw($x, "UserComment", fxBytes([0x41, 0x53, 0x43, 0x49, 0x49, 0, 0, 0, 0x68, 0x69]));
    testing.assertEqual(get($x, "UserComment").count, 10);
    testing.assertThrowsArgs("setRationals", [$x, "Make", [Rational{num: 1, den: 1}]], "exif");
    testing.assertThrowsArgs("setRaw", [$x, "Make", fxBytes([1])], "exif");
}

func testTextReader() {
    def x as Exif init set(
        empty("be"),
        makeEntry("Make", TYPE_ASCII, Value.Ascii{data: fxBytes([0x41, 0x42])}));
    testing.assertEqual(text($x, "Make"), "AB");
    $x = set($x, makeEntry("Model", TYPE_ASCII, Value.Ascii{data: fxBytes([0x41, 0, 0x42, 0])}));
    testing.assertEqual(text($x, "Model"), "A");
    $x = set($x, makeEntry("Artist", TYPE_ASCII, Value.Ascii{data: fxBytes([0x4D, 0xFC, 0])}));
    testing.assertThrowsArgs("text", [$x, "Artist"], "exif");
    testing.assertThrowsArgs("text", [fxExif(), "Orientation"], "exif");
}

func testNumberReaders() {
    def x as Exif init fxExif();
    testing.assertEqual(ints($x, "Orientation"), [6]);
    testing.assertEqual(rationals($x, "ExposureTime"), [Rational{num: 1, den: 125}]);
    testing.assertEqual(floats($x, "ExposureTime"), [0.008]);
    testing.assertEqual(floats($x, "Orientation"), [6.0]);
    $x = set($x, makeEntry("ifd0:0xC000", TYPE_FLOAT, Value.Floats{values: [0.5, 2.0]}));
    testing.assertEqual(floats($x, "ifd0:0xC000"), [0.5, 2.0]);
    testing.assertThrowsArgs("ints", [$x, "Make"], "exif");
    testing.assertThrowsArgs("rationals", [$x, "Make"], "exif");
    testing.assertThrowsArgs("floats", [$x, "Make"], "exif");
    $x = setRationals($x, "FNumber", [Rational{num: 0, den: 0}]);
    testing.assertThrowsArgs("floats", [$x, "FNumber"], "exif");
}

func testRawReader() {
    def x as Exif init setInts(empty("be"), "GPSVersionID", [2, 3, 0, 0]);
    testing.assertEqual(raw($x, "GPSVersionID"), fxBytes([2, 3, 0, 0]));
    $x = set($x, makeEntry("ifd0:0xC001", TYPE_SBYTE, Value.Ints{values: [-1, 5]}));
    testing.assertEqual(raw($x, "ifd0:0xC001"), fxBytes([255, 5]));
    $x = setRaw($x, "ExifVersion", fxBytes([0x30, 0x32, 0x33, 0x32]));
    testing.assertEqual(raw($x, "ExifVersion"), fxBytes([0x30, 0x32, 0x33, 0x32]));
    testing.assertThrowsArgs("raw", [fxExif(), "Orientation"], "exif");
    testing.assertThrowsArgs("raw", [fxExif(), "ExposureTime"], "exif");
}

func testPrivacyHelpers() {
    def x as Exif init setGps(fxExif(), 1.5, 2.5);
    $x = setThumbnail($x, fxJpeg());
    $x = setRationals($x, "ifd1:XResolution", [Rational{num: 72, den: 1}]);
    testing.assertTrue(hasGps($x));
    def noGps as Exif init removeGps($x);
    testing.assertFalse(hasGps($noGps));
    testing.assertTrue(has($noGps, "ifd1:XResolution"));
    def noThumb as Exif init removeThumbnail($x);
    testing.assertEqual(len($noThumb.thumbnail), 0);
    testing.assertFalse(has($noThumb, "ifd1:XResolution"));
    testing.assertFalse(has($noThumb, "ifd1:Compression"));
    testing.assertTrue(hasGps($noThumb));
}

func testSetThumbnail() {
    def x as Exif init setThumbnail(empty("be"), fxJpeg());
    testing.assertEqual(ints($x, "ifd1:Compression"), [6]);
    testing.assertEqual($x.thumbnail, fxJpeg());
    testing.assertThrowsArgs("setThumbnail", [empty("be"), fxPng()], "exif");
}
