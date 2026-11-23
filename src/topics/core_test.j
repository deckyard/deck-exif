# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.27.0

# exif - white-box tests for the core topic.
# Spliced into exif_test.j via include - run with:
#   jennifer test src/exif_test.j

include "fixtures/images_test.j";

func testUintBytesMatchesTheReader() {
    for (def order in ["le", "be"]) {
        for (def size in [1, 2, 4, 8]) {
            def v as int init (1 << (8 * $size - 2)) + 0x1234 % (1 << (8 * $size - 2));
            testing.assertEqual(
                binary.readUint($order, uintBytes($order, $v, $size), 0, $size),
                $v);
        }
        testing.assertEqual(uintBytes($order, 0x0A0B0C, 3), fxUint($order, 0x0A0B0C, 3));
    }
    testing.assertEqual(uintBytes("be", 0x0102, 2), fxBytes([1, 2]));
    testing.assertEqual(uintBytes("le", 0x0102, 2), fxBytes([2, 1]));
}

func testUintBytesWritesTwosComplement() {
    testing.assertEqual(binary.readInt("le", uintBytes("le", -2, 4), 0, 4), -2);
    testing.assertEqual(binary.readInt("be", uintBytes("be", -32768, 2), 0, 2), -32768);
    testing.assertEqual(uintBytes("be", -1, 1), fxBytes([255]));
}

func testFloatBitsDouble() {
    def values as list of float init [
        1.0,
        -2.5,
        0.1,
        1e300,
        -1e-300,
        5e-324,
        2.2250738585072014e-308,
        2.225073858507201e-308,
        3.141592653589793,
        0.0,
        1.7976931348623157e308,
        123456.789
    ];
    for (def v in $values) {
        for (def order in ["le", "be"]) {
            def b as bytes init uintBytes($order, floatBits($v, 8), 8);
            testing.assertEqual(binary.readFloat($order, $b, 0, 8), $v);
        }
    }
}

func testFloatBitsSingle() {
    def exact as list of float init [
        1.0,
        0.5,
        -3.25,
        1.401298464324817e-45,
        1.1754943508222875e-38,
        3.4028234663852886e38,
        0.0,
        65504.0
    ];
    for (def v in $exact) {
        def b as bytes init uintBytes("le", floatBits($v, 4), 4);
        testing.assertEqual(binary.readFloat("le", $b, 0, 4), $v);
    }
    def b as bytes init uintBytes("be", floatBits(0.1, 4), 4);
    testing.assertEqual(binary.readFloat("be", $b, 0, 4), 0.10000000149011612);
    testing.assertEqual(floatBits(1.0, 4), 0x3F800000);
    testing.assertEqual(floatBits(-2.0, 4), 0xC0000000);
}

func testFloatBitsRoundsHalfToEven() {
    # 1 + 2^-24 lies halfway between 1 and the next single; even wins
    testing.assertEqual(floatBits(1.0000000596046448, 4), 0x3F800000);
    # 1 + 3 * 2^-24 lies halfway between two singles; the even one is above
    testing.assertEqual(floatBits(1.0000001788139343, 4), 0x3F800002);
}

func testFloatBitsRefusesOverflow() {
    testing.assertThrowsArgs("floatBits", [1e39, 4], "exif");
    testing.assertThrowsArgs("floatBits", [-3.4028236e38, 4], "exif");
}

func testCapsDefaults() {
    def caps as Options init capsOf(Options{maxBytes: 0, maxEntries: 0, maxValueBytes: 0});
    testing.assertEqual($caps.maxBytes, MAX_BYTES);
    testing.assertEqual($caps.maxEntries, MAX_ENTRIES);
    testing.assertEqual($caps.maxValueBytes, MAX_VALUE_BYTES);
    $caps = capsOf(Options{maxBytes: 100, maxEntries: 5, maxValueBytes: 7});
    testing.assertEqual($caps.maxEntries, 5);
}

func testCapsOnlyGoDown() {
    testing.assertThrowsArgs(
        "capsOf",
        [Options{maxBytes: -1, maxEntries: 0, maxValueBytes: 0}],
        "exif");
    testing.assertThrowsArgs(
        "capsOf",
        [Options{maxBytes: 0, maxEntries: MAX_ENTRIES + 1, maxValueBytes: 0}],
        "exif");
}

func testNeedNamesTheOffset() {
    try {
        need(10, 4, 12, "thing");
        testing.assertTrue(false);
    } catch (e) {
        def err as ExifError init fxCaught($e);
        testing.assertEqual($err.offset, 10);
        testing.assertContains($err.message, "truncated thing");
    }
    need(8, 4, 12, "thing");
}

func testFailLimitIsKindLimit() {
    testing.assertThrowsArgs("failLimit", ["x"], "limit");
    testing.assertThrowsArgs("fail", ["x"], "exif");
}

func testHex4() {
    testing.assertEqual(hex4(0x10F), "0x010F");
    testing.assertEqual(hex4(0xA432), "0xA432");
}

func testHasAt() {
    def b as bytes init fxBytes([1, 2, 3]);
    testing.assertTrue(hasAt($b, 1, fxBytes([2, 3])));
    testing.assertFalse(hasAt($b, 2, fxBytes([3, 4])));
    testing.assertFalse(hasAt($b, -1, fxBytes([1])));
}
