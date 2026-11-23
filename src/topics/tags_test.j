# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.27.0

# exif - white-box tests for the tags topic.
# Spliced into exif_test.j via include - run with:
#   jennifer test src/exif_test.j

func testTagName() {
    testing.assertEqual(tagName(IFD0, 0x010F), "Make");
    testing.assertEqual(tagName(IFD1, 0x011A), "XResolution");
    testing.assertEqual(tagName(IFD_EXIF, 0x829A), "ExposureTime");
    testing.assertEqual(tagName(IFD_GPS, 1), "GPSLatitudeRef");
    testing.assertEqual(tagName(IFD_INTEROP, 1), "InteroperabilityIndex");
    testing.assertEqual(tagName(IFD_GPS, 0x010F), "");
    testing.assertThrowsArgs("tagName", ["ifd2", 1], "exif");
}

func testTableNamesAreUnique() {
    def names as map of string to bool init {};
    for (def t in TAGS) {
        testing.assertFalse(maps.has($names, $t.name));
        $names[$t.name] = true;
        testing.assertTrue($t.type == 0 or typeSize($t.type) > 0);
    }
}

func testResolveByName() {
    testing.assertEqual(resolve("Make"), TagRef{ifd: IFD0, id: 0x010F, type: TYPE_ASCII});
    testing.assertEqual(resolve("GPSLatitude"), TagRef{ifd: IFD_GPS, id: 2, type: TYPE_RATIONAL});
    testing.assertEqual(
        resolve("InteroperabilityIndex"),
        TagRef{ifd: IFD_INTEROP, id: 1, type: TYPE_ASCII});
    testing.assertEqual(
        resolve("ifd1:XResolution"),
        TagRef{ifd: IFD1, id: 0x011A, type: TYPE_RATIONAL});
    testing.assertEqual(resolve("ImageWidth").type, TYPE_SHORT_OR_LONG);
}

func testResolveByNumber() {
    testing.assertEqual(resolve("gps:0x0002"), TagRef{ifd: IFD_GPS, id: 2, type: TYPE_RATIONAL});
    testing.assertEqual(resolve("exif:42036"), TagRef{ifd: IFD_EXIF, id: 42036, type: TYPE_ASCII});
    testing.assertEqual(resolve("ifd0:0xC4A5"), TagRef{ifd: IFD0, id: 0xC4A5, type: -1});
    testing.assertEqual(resolve("interop:1").type, TYPE_ASCII);
}

func testResolveRefuses() {
    testing.assertThrowsArgs("resolve", ["NoSuchTag"], "exif");
    testing.assertThrowsArgs("resolve", ["ifd9:Make"], "exif");
    testing.assertThrowsArgs("resolve", ["gps:Make"], "exif");
    testing.assertThrowsArgs("resolve", ["exif:70000"], "exif");
    testing.assertThrowsArgs("resolve", ["exif:0x12345"], "exif");
    testing.assertThrowsArgs("resolve", ["1"], "exif");
}

func testTypeSize() {
    testing.assertEqual(typeSize(TYPE_BYTE), 1);
    testing.assertEqual(typeSize(TYPE_ASCII), 1);
    testing.assertEqual(typeSize(TYPE_SHORT), 2);
    testing.assertEqual(typeSize(TYPE_LONG), 4);
    testing.assertEqual(typeSize(TYPE_RATIONAL), 8);
    testing.assertEqual(typeSize(TYPE_SBYTE), 1);
    testing.assertEqual(typeSize(TYPE_UNDEFINED), 1);
    testing.assertEqual(typeSize(TYPE_SSHORT), 2);
    testing.assertEqual(typeSize(TYPE_SLONG), 4);
    testing.assertEqual(typeSize(TYPE_SRATIONAL), 8);
    testing.assertEqual(typeSize(TYPE_FLOAT), 4);
    testing.assertEqual(typeSize(TYPE_DOUBLE), 8);
    testing.assertEqual(typeSize(0), 0);
    testing.assertEqual(typeSize(13), 0);
}
