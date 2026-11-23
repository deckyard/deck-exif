# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.27.0

# exif - white-box tests for the readers topic.
# Spliced into exif_test.j via include - run with:
#   jennifer test src/exif_test.j

func testOrientation() {
    testing.assertEqual(orientation(fxExif()), 6);
    testing.assertThrowsArgs("orientation", [empty("be")], "exif");
    testing.assertThrowsArgs("orientation", [setInts(empty("be"), "Orientation", [9])], "exif");
    testing.assertThrowsArgs("orientation", [setInts(empty("be"), "Orientation", [1, 1])], "exif");
}

# GPS tags as a camera writes them: degrees, minutes, seconds / 100.
func fxGpsExif(latRef as string, lonRef as string) {
    def x as Exif init setText(empty("be"), "GPSLatitudeRef", $latRef);
    $x = setRationals(
        $x,
        "GPSLatitude",
        [Rational{num: 48, den: 1}, Rational{num: 12, den: 1}, Rational{num: 2952, den: 100}]);
    $x = setText($x, "GPSLongitudeRef", $lonRef);
    $x = setRationals(
        $x,
        "GPSLongitude",
        [Rational{num: 16, den: 1}, Rational{num: 22, den: 1}, Rational{num: 2568, den: 100}]);
    return $x;
}

func testGps() {
    def x as Exif init fxGpsExif("N", "E");
    testing.assertTrue(hasGps($x));
    def g as Gps init gps($x);
    testing.assertTrue(math.abs($g.latitude - 48.2082) < 1e-9);
    testing.assertTrue(math.abs($g.longitude - 16.3738) < 1e-9);
    testing.assertFalse($g.hasAltitude);
    $g = gps(fxGpsExif("S", "W"));
    testing.assertTrue($g.latitude < -48.0);
    testing.assertTrue($g.longitude < -16.0);
    testing.assertFalse(hasGps(empty("be")));
}

func testGpsAltitude() {
    def x as Exif init setRationals(
        fxGpsExif("N", "E"),
        "GPSAltitude",
        [Rational{num: 2155, den: 10}]);
    testing.assertEqual(gps($x).altitude, 215.5);
    testing.assertTrue(gps($x).hasAltitude);
    $x = setInts($x, "GPSAltitudeRef", [1]);
    testing.assertEqual(gps($x).altitude, -215.5);
    testing.assertThrowsArgs("gps", [setInts($x, "GPSAltitudeRef", [2])], "exif");
    testing.assertThrowsArgs(
        "gps",
        [setRationals($x, "GPSAltitude", [Rational{num: 1, den: 0}])],
        "exif");
}

func testGpsRefuses() {
    testing.assertThrowsArgs("gps", [fxGpsExif("X", "E")], "exif");
    testing.assertThrowsArgs("gps", [fxGpsExif("N", "N")], "exif");
    def x as Exif init setRationals(
        fxGpsExif("N", "E"),
        "GPSLatitude",
        [Rational{num: 48, den: 1}]);
    testing.assertThrowsArgs("gps", [$x], "exif");
    $x = setRationals(
        fxGpsExif("N", "E"),
        "GPSLatitude",
        [Rational{num: 48, den: 0}, Rational{num: 0, den: 1}, Rational{num: 0, den: 1}]);
    testing.assertThrowsArgs("gps", [$x], "exif");
    testing.assertThrowsArgs("gps", [empty("be")], "exif");
}

func testSetGps() {
    def coords as list of list of float init [
        [48.2082, 16.3738],
        [-33.8568, 151.2153],
        [0.0, -180.0],
        [90.0, 0.000001]
    ];
    for (def c in $coords) {
        def x as Exif init setGps(empty("le"), $c[0], $c[1]);
        def g as Gps init gps($x);
        testing.assertTrue(math.abs($g.latitude - $c[0]) < 1e-9);
        testing.assertTrue(math.abs($g.longitude - $c[1]) < 1e-9);
        testing.assertEqual(ints($x, "GPSVersionID"), [2, 3, 0, 0]);
        testing.assertEqual(parse(render($x)), $x);
    }
    def kept as Exif init setGps(setInts(empty("be"), "GPSVersionID", [2, 2, 0, 0]), 1.0, 1.0);
    testing.assertEqual(ints($kept, "GPSVersionID"), [2, 2, 0, 0]);
    testing.assertThrowsArgs("setGps", [empty("be"), 90.5, 0.0], "exif");
    testing.assertThrowsArgs("setGps", [empty("be"), 0.0, -180.1], "exif");
}

func testDms() {
    testing.assertEqual(
        dms(48.2082),
        [
            Rational{num: 48, den: 1},
            Rational{num: 12, den: 1},
            Rational{num: 29520000, den: 1000000}
        ]);
    # rounding up to a whole minute carries
    testing.assertEqual(
        dms(10.0 - 1e-12),
        [Rational{num: 10, den: 1}, Rational{num: 0, den: 1}, Rational{num: 0, den: 1000000}]);
}

func testDateTime() {
    def x as Exif init setText(empty("be"), "DateTimeOriginal", "2026:11:23 14:05:09");
    def t as time.Time init dateTime($x, "DateTimeOriginal", time.UTC);
    testing.assertEqual(time.iso($t), "2026-11-23T14:05:09Z");
    $t = dateTime($x, "DateTimeOriginal", time.zone(3600, "CET"));
    testing.assertEqual(time.unix($t), time.unix(time.fromIso("2026-11-23T13:05:09Z")));
    $x = setText($x, "OffsetTimeOriginal", "-05:30");
    $x = setText($x, "SubSecTimeOriginal", "25");
    $t = dateTime($x, "DateTimeOriginal", time.UTC);
    testing.assertEqual(
        time.unixMillis($t),
        time.unixMillis(time.fromIso("2026-11-23T19:35:09.25Z")));
}

func testDateTimeTags() {
    def x as Exif init setText(empty("be"), "DateTime", "2020:01:02 03:04:05");
    $x = setText($x, "OffsetTime", "+02:00");
    $x = setText($x, "DateTimeDigitized", "2020:01:02 03:04:06");
    testing.assertEqual(
        time.unix(dateTime($x, "DateTime", time.UTC)),
        time.unix(time.fromIso("2020-01-02T01:04:05Z")));
    testing.assertEqual(
        time.unix(dateTime($x, "DateTimeDigitized", time.UTC)),
        time.unix(time.fromIso("2020-01-02T03:04:06Z")));
}

func testDateTimeRefuses() {
    def x as Exif init setText(empty("be"), "DateTimeOriginal", "    :  :     :  :  ");
    testing.assertThrowsArgs("dateTime", [$x, "DateTimeOriginal", time.UTC], "exif");
    $x = setText($x, "DateTimeOriginal", "2026:13:40 10:00:00");
    testing.assertThrowsArgs("dateTime", [$x, "DateTimeOriginal", time.UTC], "exif");
    $x = setText($x, "DateTimeOriginal", "2026:01:01 10:00:00");
    testing.assertThrowsArgs("dateTime", [$x, "Make", time.UTC], "exif");
    testing.assertThrowsArgs("dateTime", [$x, "DateTime", time.UTC], "exif");
    testing.assertThrowsArgs(
        "dateTime",
        [setText($x, "OffsetTimeOriginal", "CET"), "DateTimeOriginal", time.UTC],
        "exif");
    testing.assertThrowsArgs(
        "dateTime",
        [setText($x, "SubSecTimeOriginal", "x"), "DateTimeOriginal", time.UTC],
        "exif");
}

func testGpsTime() {
    def x as Exif init setText(empty("be"), "GPSDateStamp", "2026:11:23");
    $x = setRationals(
        $x,
        "GPSTimeStamp",
        [Rational{num: 13, den: 1}, Rational{num: 4, den: 1}, Rational{num: 5125, den: 100}]);
    def t as time.Time init gpsTime($x);
    testing.assertEqual(
        time.unixMillis($t),
        time.unixMillis(time.fromIso("2026-11-23T13:04:51.25Z")));
    testing.assertThrowsArgs("gpsTime", [setText($x, "GPSDateStamp", "2026-11-23")], "exif");
    testing.assertThrowsArgs(
        "gpsTime",
        [setRationals($x, "GPSTimeStamp", [Rational{num: 1, den: 1}])],
        "exif");
    def half as list of Rational init [
        Rational{num: 13, den: 2},
        Rational{num: 4, den: 1},
        Rational{num: 5, den: 1}
    ];
    testing.assertThrowsArgs("gpsTime", [setRationals($x, "GPSTimeStamp", $half)], "exif");
    def zero as list of Rational init [
        Rational{num: 13, den: 1},
        Rational{num: 4, den: 1},
        Rational{num: 5, den: 0}
    ];
    testing.assertThrowsArgs("gpsTime", [setRationals($x, "GPSTimeStamp", $zero)], "exif");
    testing.assertThrowsArgs("gpsTime", [empty("be")], "exif");
}

func testDescribe() {
    def x as Exif init fxExif();
    testing.assertEqual(describe(get($x, "Make")), "Jennifer");
    testing.assertEqual(describe(get($x, "ExposureTime")), "1/125");
    testing.assertEqual(
        describe(makeEntry("ifd0:0xC000", TYPE_SHORT, Value.Ints{values: [1, 2]})),
        "1, 2");
    testing.assertEqual(
        describe(makeEntry("ifd0:0xC000", TYPE_DOUBLE, Value.Floats{values: [0.5]})),
        "0.5");
    testing.assertEqual(
        describe(makeEntry(
            "ExifVersion",
            TYPE_UNDEFINED,
            Value.Undefined{data: fxBytes([0x30, 0xAB])})),
        "30 ab");
    testing.assertEqual(
        describe(makeEntry("MakerNote", TYPE_UNDEFINED, Value.Undefined{data: binary.make(17)})),
        "(17 bytes)");
    testing.assertEqual(
        describe(makeEntry("Artist", TYPE_ASCII, Value.Ascii{data: fxBytes([0xFC, 0])})),
        "fc 00");
}
