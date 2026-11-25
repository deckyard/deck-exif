# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.28.0

# exif - white-box tests for the tiff topic.
# Spliced into exif_test.j via include - run with:
#   jennifer test src/exif_test.j

# Integers as `size`-byte values in `order`.
func fxInts(order as string, values as list of int, size as int) {
    def parts as list of bytes init [];
    for (def v in $values) {
        $parts[] = fxUint($order, $v, $size);
    }
    return binary.join($parts);
}

# Rationals as pairs of 4-byte values.
func fxRats(order as string, values as list of Rational) {
    def parts as list of bytes init [];
    for (def r in $values) {
        $parts[] = fxUint($order, $r.num, 4);
        $parts[] = fxUint($order, $r.den, 4);
    }
    return binary.join($parts);
}

# One entry of every field type, inline and out of line, as raw entries
# (tags 0xC000 up, in order) and as the entries `parse` should give.
func fxAllRaw(order as string) {
    def r1 as list of Rational init [Rational{num: 1, den: 2}];
    def r2 as list of Rational init [Rational{num: 4294967295, den: 1}, Rational{num: 3, den: 4}];
    def s1 as list of Rational init [Rational{num: -1, den: 3}];
    def s2 as list of Rational init [
        Rational{num: -2147483648, den: 2147483647},
        Rational{num: 5, den: -7}
    ];
    return [
        fxEntry(0xC000, 1, 2, fxBytes([1, 255])),
        fxEntry(0xC001, 1, 10, fxBytes([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])),
        fxEntry(0xC002, 2, 3, fxText("ab")),
        fxEntry(0xC003, 2, 12, fxText("Hello, EXIF")),
        fxEntry(0xC004, 3, 2, fxInts($order, [1, 65535], 2)),
        fxEntry(0xC005, 3, 3, fxInts($order, [1, 2, 3], 2)),
        fxEntry(0xC006, 4, 1, fxInts($order, [4294967295], 4)),
        fxEntry(0xC007, 4, 2, fxInts($order, [1, 2], 4)),
        fxEntry(0xC008, 5, 1, fxRats($order, $r1)),
        fxEntry(0xC009, 5, 2, fxRats($order, $r2)),
        fxEntry(0xC00A, 6, 3, fxBytes([128, 127, 255])),
        fxEntry(0xC00B, 6, 5, fxBytes([255, 255, 255, 255, 255])),
        fxEntry(0xC00C, 7, 4, fxBytes([0, 1, 2, 3])),
        fxEntry(0xC00D, 7, 5, fxBytes([9, 9, 9, 9, 9])),
        fxEntry(0xC00E, 8, 2, fxInts($order, [-32768, 32767], 2)),
        fxEntry(0xC00F, 8, 3, fxInts($order, [-1, -2, -3], 2)),
        fxEntry(0xC010, 9, 1, fxInts($order, [-2147483648], 4)),
        fxEntry(0xC011, 9, 2, fxInts($order, [1, -1], 4)),
        fxEntry(0xC012, 10, 1, fxRats($order, $s1)),
        fxEntry(0xC013, 10, 2, fxRats($order, $s2)),
        fxEntry(0xC014, 11, 1, fxInts($order, [0x3FC00000], 4)),
        fxEntry(0xC015, 11, 2, fxInts($order, [0x3E800000, 0xC1000000], 4)),
        fxEntry(0xC016, 12, 1, fxInts($order, [0x400921FB54442D18], 8)),
        fxEntry(0xC017, 12, 2, fxInts($order, [0x7E37E43C8800759C, -4610560118520545280], 8)),
        fxEntry(0xC018, 1, 0, fxBytes([]))
    ];
}

func fxAllEntries() {
    def r1 as list of Rational init [Rational{num: 1, den: 2}];
    def r2 as list of Rational init [Rational{num: 4294967295, den: 1}, Rational{num: 3, den: 4}];
    def s1 as list of Rational init [Rational{num: -1, den: 3}];
    def s2 as list of Rational init [
        Rational{num: -2147483648, den: 2147483647},
        Rational{num: 5, den: -7}
    ];
    def vs as list of Value init [
        Value.Ints{values: [1, 255]},
        Value.Ints{values: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]},
        Value.Ascii{data: fxText("ab")},
        Value.Ascii{data: fxText("Hello, EXIF")},
        Value.Ints{values: [1, 65535]},
        Value.Ints{values: [1, 2, 3]},
        Value.Ints{values: [4294967295]},
        Value.Ints{values: [1, 2]},
        Value.Rationals{values: $r1},
        Value.Rationals{values: $r2},
        Value.Ints{values: [-128, 127, -1]},
        Value.Ints{values: [-1, -1, -1, -1, -1]},
        Value.Undefined{data: fxBytes([0, 1, 2, 3])},
        Value.Undefined{data: fxBytes([9, 9, 9, 9, 9])},
        Value.Ints{values: [-32768, 32767]},
        Value.Ints{values: [-1, -2, -3]},
        Value.Ints{values: [-2147483648]},
        Value.Ints{values: [1, -1]},
        Value.Rationals{values: $s1},
        Value.Rationals{values: $s2},
        Value.Floats{values: [1.5]},
        Value.Floats{values: [0.25, -8.0]},
        Value.Floats{values: [3.141592653589793]},
        Value.Floats{values: [1e300, -2.5]},
        Value.Ints{values: []}
    ];
    def types as list of int init [
        1,
        1,
        2,
        2,
        3,
        3,
        4,
        4,
        5,
        5,
        6,
        6,
        7,
        7,
        8,
        8,
        9,
        9,
        10,
        10,
        11,
        11,
        12,
        12,
        1
    ];
    def out as list of Entry init [];
    for (def i in 0..len($vs)) {
        $out[] = Entry{
            ifd: IFD0,
            tag: 0xC000 + $i,
            type: $types[$i],
            count: valueCount($vs[$i]),
            value: $vs[$i]
        };
    }
    return $out;
}

func testParseEveryTypeInBothOrders() {
    for (def order in ["le", "be"]) {
        def x as Exif init parse(fxPayload($order, fxAllRaw($order)));
        testing.assertEqual($x.order, $order);
        testing.assertEqual(len($x.thumbnail), 0);
        def want as list of Entry init fxAllEntries();
        testing.assertEqual(len($x.entries), len($want));
        for (def i in 0..len($want)) {
            testing.assertEqual($x.entries[$i], $want[$i]);
        }
    }
}

func testRenderRoundTripsEveryType() {
    for (def order in ["le", "be"]) {
        def x as Exif init empty($order);
        $x.entries = fxAllEntries();
        testing.assertEqual(parse(render($x)), $x);
    }
}

func testRenderMatchesAHandBuiltPayload() {
    # sorted entries, values after the table: what fxIfd writes when every
    # out-of-line value has an even length
    def raw as list of FxEntry init [
        fxEntry(0x010F, 2, 4, fxText("ABC")),
        fxEntry(0x0110, 2, 6, fxText("Model")),
        fxEntry(0x011A, 5, 1, fxRats("be", [Rational{num: 72, den: 1}]))
    ];
    def x as Exif init parse(fxPayload("be", $raw));
    testing.assertEqual(render($x), fxPayload("be", $raw));
}

# A payload with all five IFDs and a thumbnail. `exifAt` overrides the Exif
# IFD pointer when not 0 (to build a loop).
func fxFull(order as string, exifAt as int) {
    def make as FxEntry init fxEntry(0x010F, 2, 9, fxText("Jennifer"));
    def thumb as bytes init fxJpeg();
    def exifIfd as list of FxEntry init [
        fxEntry(0x829A, 5, 1, fxRats($order, [Rational{num: 1, den: 60}])),
        fxLong($order, 0xA005, 0)
    ];
    def interop as list of FxEntry init [fxEntry(0x0001, 2, 4, fxText("R98"))];
    def gpsIfd as list of FxEntry init [
        fxEntry(0x0000, 1, 4, fxBytes([2, 3, 0, 0])),
        fxEntry(0x0001, 2, 2, fxText("N"))
    ];
    def ifd1 as list of FxEntry init [
        fxEntry(0x0103, 3, 1, fxInts($order, [6], 2)),
        fxLong($order, 0x0201, 0),
        fxLong($order, 0x0202, len($thumb))
    ];
    def ifd0Size as int init fxIfdSize([
        $make,
        fxLong($order, 0x8769, 0),
        fxLong($order, 0x8825, 0)
    ]);
    def exifOff as int init 8 + $ifd0Size;
    def interopOff as int init $exifOff + fxIfdSize($exifIfd);
    def gpsOff as int init $interopOff + fxIfdSize($interop);
    def ifd1Off as int init $gpsOff + fxIfdSize($gpsIfd);
    def thumbOff as int init $ifd1Off + fxIfdSize($ifd1);
    def exifPtr as int init $exifOff;
    if ($exifAt != 0) {
        $exifPtr = $exifAt;
    }
    $exifIfd[1] = fxLong($order, 0xA005, $interopOff);
    $ifd1[1] = fxLong($order, 0x0201, $thumbOff);
    def ifd0 as list of FxEntry init [
        $make,
        fxLong($order, 0x8769, $exifPtr),
        fxLong($order, 0x8825, $gpsOff)
    ];
    return binary.join([
        fxHeader($order, 8),
        fxIfd($order, 8, $ifd0, $ifd1Off),
        fxIfd($order, $exifOff, $exifIfd, 0),
        fxIfd($order, $interopOff, $interop, 0),
        fxIfd($order, $gpsOff, $gpsIfd, 0),
        fxIfd($order, $ifd1Off, $ifd1, 0),
        $thumb
    ]);
}

func testParseAllIfds() {
    for (def order in ["le", "be"]) {
        def x as Exif init parse(fxFull($order, 0));
        def got as list of string init [];
        for (def e in $x.entries) {
            $got[] = $e.ifd + ":" + hex4($e.tag);
        }
        testing.assertEqual(
            $got,
            [
                "ifd0:0x010F",
                "exif:0x829A",
                "interop:0x0001",
                "gps:0x0000",
                "gps:0x0001",
                "ifd1:0x0103"
            ]);
        testing.assertEqual($x.thumbnail, fxJpeg());
        testing.assertEqual(text($x, "Make"), "Jennifer");
        testing.assertEqual(text($x, "InteroperabilityIndex"), "R98");
        testing.assertEqual(text($x, "GPSLatitudeRef"), "N");
        testing.assertEqual(rationals($x, "ExposureTime"), [Rational{num: 1, den: 60}]);
        testing.assertEqual(parse(render($x)), $x);
    }
}

func testRenderAlignsValues() {
    def x as Exif init setText(empty("le"), "Make", "Odd!");
    $x = setText($x, "Model", "Also");
    def b as bytes init render($x);
    # IFD0 at 8 with two entries: value offsets at 8 + 2 + 8 and 8 + 2 + 12 + 8
    testing.assertEqual(binary.readUint("le", $b, 18, 4), 8 + 2 + 24 + 4);
    testing.assertEqual(binary.readUint("le", $b, 30, 4), 8 + 2 + 24 + 4 + 6);
    $x = setThumbnail($x, fxJpeg());
    $b = render($x);
    def back as Exif init parse($b);
    testing.assertEqual($back.thumbnail, fxJpeg());
}

func testRenderWritesOnlyIfdsWithEntries() {
    def x as Exif init setText(empty("be"), "Make", "A");
    def b as bytes init render($x);
    testing.assertEqual(binary.readUint("be", $b, 8, 2), 1);
    testing.assertEqual(binary.readUint("be", $b, 8 + 2 + 12, 4), 0);
    # only the Interop IFD has entries: the Exif IFD is written for its pointer
    $x = setText(empty("be"), "InteroperabilityIndex", "R98");
    def back as Exif init parse(render($x));
    testing.assertEqual($back, $x);
    testing.assertEqual(binary.readUint("be", render($x), 10, 2), 0x8769);
}

func testRenderRefuses() {
    def x as Exif init empty("be");
    $x.entries = [
        Entry{ifd: IFD0, tag: 1, type: 3, count: 1, value: Value.Ints{values: [1]}},
        Entry{ifd: IFD0, tag: 1, type: 3, count: 1, value: Value.Ints{values: [2]}}
    ];
    testing.assertThrowsArgs("render", [$x], "exif");
    $x.entries = [];
    $x.order = "xx";
    testing.assertThrowsArgs("render", [$x], "exif");
    $x = empty("le");
    $x.entries = [Entry{ifd: IFD0, tag: 0x0111, type: 4, count: 1, value: Value.Ints{values: [1]}}];
    testing.assertThrowsArgs("render", [$x], "exif");
}

func testRenderRefusesWhatParseCaps() {
    # render used to write these, and parse then refused its own output
    def big as Exif init setRaw(empty("le"), "MakerNote", binary.make(MAX_VALUE_BYTES + 1));
    testing.assertThrowsArgs("render", [$big], "limit");
    def atCap as Exif init setRaw(empty("le"), "MakerNote", binary.make(MAX_VALUE_BYTES));
    testing.assertEqual(parse(render($atCap)), $atCap);
    def thumb as bytes init binary.make(MAX_VALUE_BYTES + 1);
    $thumb[0] = 0xFF;
    $thumb[1] = 0xD8;
    testing.assertThrowsArgs("render", [setThumbnail(empty("le"), $thumb)], "limit");
    # IFD0 with MAX_ENTRIES entries plus the Exif pointer
    def many as Exif init setText(empty("be"), "LensMake", "L");
    def entries as list of Entry init [];
    for (def i in 0..MAX_ENTRIES) {
        $entries[] = Entry{
            ifd: IFD0,
            tag: 0xC000 + $i,
            type: 1,
            count: 1,
            value: Value.Ints{values: [1]}
        };
    }
    $entries[] = $many.entries[0];
    $many.entries = $entries;
    testing.assertThrowsArgs("render", [$many], "limit");
}

# The offset an ExifError reports for a payload.
func fxOffsetOf(payload as bytes) {
    try {
        parse($payload);
    } catch (e) {
        return fxCaught($e).offset;
    }
    return -2;
}

func testParseRefusesABadHeader() {
    testing.assertEqual(fxOffsetOf(fxBytes([0x49, 0x49, 42, 0])), 0);
    testing.assertEqual(fxOffsetOf(fxBytes([0x49, 0x4D, 42, 0, 8, 0, 0, 0])), 0);
    testing.assertEqual(fxOffsetOf(fxBytes([0x49, 0x49, 43, 0, 8, 0, 0, 0])), 2);
    testing.assertEqual(fxOffsetOf(fxBytes([0x4D, 0x4D, 0, 42, 0, 0, 0, 4])), 4);
}

func testParseRefusesOffsetsPastTheEnd() {
    # IFD0 past the end
    testing.assertEqual(fxOffsetOf(fxHeader("be", 100)), 100);
    # an IFD whose table runs past the end
    def p as bytes init fxPayload("be", [fxEntry(0x010F, 2, 9, fxText("Jennifer"))]);
    testing.assertTrue(fxOffsetOf($p[0..20]) >= 0);
    # a value past the end
    def raw as bytes init fxPayload("be", [fxEntry(0x010F, 2, 9, fxText("Jennifer"))]);
    testing.assertEqual(fxOffsetOf($raw[0..len($raw) - 1]), 18);
    # a value offset into the header
    def bad as bytes init binary.join([
        fxHeader("le", 8),
        fxUint("le", 1, 2),
        fxUint("le", 0x010F, 2),
        fxUint("le", 2, 2),
        fxUint("le", 9, 4),
        fxUint("le", 2, 4),
        fxUint("le", 0, 4),
        fxText("Jennifer")
    ]);
    testing.assertEqual(fxOffsetOf($bad), 18);
}

func testParseRefusesALoop() {
    testing.assertThrowsArgs("parse", [fxFull("be", 8)], "exif");
    testing.assertThrowsArgs("parse", [fxFull("le", 8)], "exif");
    # IFD0 linking to itself as IFD1
    def p as bytes init binary.concat(
        fxHeader("be", 8),
        fxIfd("be", 8, [fxEntry(0x0112, 3, 1, fxInts("be", [1], 2))], 8));
    testing.assertThrowsArgs("parse", [$p], "exif");
}

func testParseRefusesExtraLinks() {
    # IFD1 links on to an IFD2
    def e as FxEntry init fxEntry(0x0112, 3, 1, fxInts("be", [1], 2));
    def size as int init fxIfdSize([$e]);
    def p as bytes init binary.join([
        fxHeader("be", 8),
        fxIfd("be", 8, [$e], 8 + $size),
        fxIfd("be", 8 + $size, [$e], 8 + 2 * $size),
        fxIfd("be", 8 + 2 * $size, [$e], 0)
    ]);
    testing.assertThrowsArgs("parse", [$p], "exif");
    # a sub-IFD with a next link
    def q as bytes init binary.join([
        fxHeader("be", 8),
        fxIfd("be", 8, [fxLong("be", 0x8769, 8 + $size)], 0),
        fxIfd("be", 8 + $size, [$e], 8)
    ]);
    testing.assertThrowsArgs("parse", [$q], "exif");
}

func testParseRefusesBadEntries() {
    def e as FxEntry init fxEntry(0x0112, 3, 1, fxInts("be", [1], 2));
    testing.assertThrowsArgs("parse", [fxPayload("be", [$e, $e])], "exif");
    testing.assertThrowsArgs(
        "parse",
        [fxPayload("be", [fxEntry(0x0112, 13, 1, fxBytes([0, 0, 0, 1]))])],
        "exif");
    testing.assertThrowsArgs(
        "parse",
        [fxPayload("be", [fxEntry(0x0112, 0, 1, fxBytes([0, 0, 0, 1]))])],
        "exif");
    # pointer tags out of place or of the wrong type
    testing.assertThrowsArgs("parse", [fxPayload("be", [fxLong("be", 0xA005, 8)])], "exif");
    testing.assertThrowsArgs("parse", [fxPayload("be", [fxLong("be", 0x0201, 8)])], "exif");
    testing.assertThrowsArgs(
        "parse",
        [fxPayload("be", [fxEntry(0x8769, 3, 1, fxInts("be", [8], 2))])],
        "exif");
    testing.assertThrowsArgs(
        "parse",
        [fxPayload("be", [fxEntry(0x8769, 4, 2, fxInts("be", [8, 8], 4))])],
        "exif");
    # a NaN float
    testing.assertThrowsArgs(
        "parse",
        [fxPayload("be", [fxEntry(0xC000, 11, 1, fxInts("be", [0x7FC00000], 4))])],
        "exif");
}

func testParseRefusesHalfAThumbnail() {
    def e as FxEntry init fxEntry(0x0103, 3, 1, fxInts("be", [6], 2));
    def size as int init fxIfdSize([$e]);
    def p as bytes init binary.join([
        fxHeader("be", 8),
        fxIfd("be", 8, [$e], 8 + $size),
        fxIfd("be", 8 + $size, [$e, fxLong("be", 0x0201, 100)], 0)
    ]);
    testing.assertThrowsArgs("parse", [$p], "exif");
    def q as bytes init binary.join([
        fxHeader("be", 8),
        fxIfd("be", 8, [$e], 8 + $size),
        fxIfd("be", 8 + $size, [fxLong("be", 0x0201, 8), fxLong("be", 0x0202, 1000)], 0)
    ]);
    testing.assertThrowsArgs("parse", [$q], "exif");
}

func testParseCaps() {
    def three as list of FxEntry init [
        fxEntry(1, 3, 1, fxInts("be", [1], 2)),
        fxEntry(2, 3, 1, fxInts("be", [1], 2)),
        fxEntry(3, 3, 1, fxInts("be", [1], 2))
    ];
    def p as bytes init fxPayload("be", $three);
    testing.assertEqual(
        len(parseWith($p, Options{maxBytes: 0, maxEntries: 3, maxValueBytes: 0}).entries),
        3);
    testing.assertThrowsArgs(
        "parseWith",
        [$p, Options{maxBytes: 0, maxEntries: 2, maxValueBytes: 0}],
        "limit");
    testing.assertThrowsArgs(
        "parseWith",
        [$p, Options{maxBytes: 20, maxEntries: 0, maxValueBytes: 0}],
        "limit");
    testing.assertThrowsArgs(
        "parseWith",
        [$p, Options{maxBytes: 0, maxEntries: 0, maxValueBytes: 1}],
        "limit");
    testing.assertThrowsArgs(
        "parseWith",
        [$p, Options{maxBytes: -5, maxEntries: 0, maxValueBytes: 0}],
        "exif");
    # a count of a billion: over the value cap before it is past the end
    def huge as bytes init fxPayload("be", [fxEntry(0x010F, 4, 1000000000, fxInts("be", [8], 4))]);
    testing.assertThrowsArgs("parse", [$huge], "limit");
    # an IFD claiming 65535 entries
    def many as bytes init binary.concat(fxHeader("le", 8), fxUint("le", 65535, 2));
    testing.assertThrowsArgs("parse", [$many], "limit");
}

# A little-endian payload whose IFD0 has `n` entries of one type and count,
# all pointing at the same value bytes after the table.
func fxShared(n as int, type as int, count as int, size as int) {
    def valueAt as int init 8 + 2 + 12 * $n + 4;
    def parts as list of bytes init [fxHeader("le", 8), fxUint("le", $n, 2)];
    for (def i in 0..$n) {
        $parts[] = fxUint("le", 0xC000 + $i, 2);
        $parts[] = fxUint("le", $type, 2);
        $parts[] = fxUint("le", $count, 4);
        $parts[] = fxUint("le", $valueAt, 4);
    }
    $parts[] = fxUint("le", 0, 4);
    $parts[] = binary.make($count * $size);
    return binary.join($parts);
}

func testParseCapsWhatValuesDecodeTo() {
    # one 1 MiB BYTE value used to take 2 GB of memory, and values sharing
    # their bytes multiplied that within the payload cap
    testing.assertThrowsArgs("parse", [fxShared(1, 1, MAX_NUMBERS + 1, 1)], "limit");
    testing.assertThrowsArgs("parse", [fxShared(3, 3, MAX_NUMBERS // 2, 2)], "limit");
    testing.assertThrowsArgs("parse", [fxShared(2, 5, MAX_NUMBERS // 4 + 1, 8)], "limit");
    testing.assertEqual(len(parse(fxShared(2, 3, MAX_NUMBERS // 2, 2)).entries), 2);
    # raw bytes do not count as numbers, but their total is capped
    testing.assertEqual(len(parse(fxShared(20, 7, 100000, 1)).entries), 20);
    testing.assertThrowsArgs("parse", [fxShared(17, 7, MAX_VALUE_BYTES, 1)], "limit");
    testing.assertThrowsArgs(
        "parseWith",
        [fxShared(3, 7, 1000, 1), Options{maxBytes: 2999, maxEntries: 0, maxValueBytes: 0}],
        "limit");
    # render refuses what parse would
    def zeros as list of int init [];
    for (def i in 0..MAX_NUMBERS) {
        $zeros[] = 0;
    }
    def x as Exif init set(
        empty("be"),
        makeEntry("exif:0xC000", TYPE_BYTE, Value.Ints{values: $zeros}));
    testing.assertEqual(parse(render($x)), $x);
    $x = set($x, makeEntry("exif:0xC001", TYPE_BYTE, Value.Ints{values: [1]}));
    testing.assertThrowsArgs("render", [$x], "limit");
}

func testParseKeepsUnsortedEntriesSorted() {
    def p as bytes init fxPayload(
        "be",
        [fxEntry(0x0112, 3, 1, fxInts("be", [1], 2)), fxEntry(0x010F, 2, 2, fxText("A"))]);
    def x as Exif init parse($p);
    testing.assertEqual($x.entries[0].tag, 0x010F);
    testing.assertEqual($x.entries[1].tag, 0x0112);
}
