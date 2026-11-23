# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.27.0

# exif - test fixtures: small images and a TIFF builder that is independent
# of the deck's writer. Included by core_test.j; every later overlay uses it.

# 3x2 lossy WebP (VP8), made by ImageMagick 7.1: magick -size 3x2 xc:red s.webp
def const WEBP_LOSSY_BASE64 as string init "UklGRjwAAABXRUJQVlA4IDAAAADQAQCdASoDAAIAAgA0JaACdLoB+AADsAD+8MQL/yC5YXXI1/8gP+QH/ID/+PIAAAA=";

# 3x2 lossless WebP (VP8L) without alpha: -define webp:lossless=true
def const WEBP_LOSSLESS_BASE64 as string init "UklGRhwAAABXRUJQVlA4TA8AAAAvAkAAAAcQ/Y/+ByKi/wEA";

# 3x2 lossless WebP (VP8L) with the alpha bit: xc:none
def const WEBP_ALPHA_BASE64 as string init "UklGRhoAAABXRUJQVlA4TA0AAAAvAkAAEAcQERGIiP4HAA==";

/**
 * One raw IFD entry for the builder.
 *
 * @field tag {int} the tag number
 * @field type {int} the field type
 * @field count {int} the count
 * @field value {bytes} the value bytes, `count` times the type size
 */
def struct FxEntry {
    tag as int,
    type as int,
    count as int,
    value as bytes
};

func fxB64(text as string) {
    return encoding.fromText("base64", $text);
}

func fxJpeg() {
    return images.encode("jpeg", images.create(4, 4));
}

func fxPng() {
    return images.encode("png", images.create(2, 2));
}

func fxWebp() {
    return fxB64(WEBP_LOSSY_BASE64);
}

# Bytes from a list of byte values.
func fxBytes(values as list of int) {
    def out as bytes;
    for (def v in $values) {
        $out[] = $v;
    }
    return $out;
}

# ASCII text with its closing NUL.
func fxText(s as string) {
    def out as bytes init encoding.encode("utf-8", $s);
    $out[] = 0;
    return $out;
}

# Big- or little-endian integer bytes, written without the deck's uintBytes.
func fxUint(order as string, value as int, size as int) {
    def out as bytes;
    for (def i in 0..$size) {
        def shift as int init 8 * $i;
        if ($order == "be") {
            $shift = 8 * ($size - 1 - $i);
        }
        $out[] = ($value >> $shift) & 0xff;
    }
    return $out;
}

func fxEntry(tag as int, type as int, count as int, value as bytes) {
    return FxEntry{tag: $tag, type: $type, count: $count, value: $value};
}

# A one-LONG entry, such as an IFD pointer.
func fxLong(order as string, tag as int, value as int) {
    return fxEntry($tag, 4, 1, fxUint($order, $value, 4));
}

# The bytes an IFD built by fxIfd takes.
func fxIfdSize(entries as list of FxEntry) {
    def size as int init 2 + 12 * len($entries) + 4;
    for (def e in $entries) {
        if (len($e.value) > 4) {
            $size = $size + len($e.value);
        }
    }
    return $size;
}

# An IFD at offset `at`: the table in the given order, then the values that
# do not fit, unpadded (so odd offsets occur), then nothing else.
func fxIfd(order as string, at as int, entries as list of FxEntry, next as int) {
    def table as list of bytes init [fxUint($order, len($entries), 2)];
    def values as list of bytes init [];
    def valueAt as int init $at + 2 + 12 * len($entries) + 4;
    for (def e in $entries) {
        $table[] = fxUint($order, $e.tag, 2);
        $table[] = fxUint($order, $e.type, 2);
        $table[] = fxUint($order, $e.count, 4);
        if (len($e.value) > 4) {
            $table[] = fxUint($order, $valueAt, 4);
            $values[] = $e.value;
            $valueAt = $valueAt + len($e.value);
        } else {
            $table[] = $e.value;
            $table[] = binary.make(4 - len($e.value));
        }
    }
    $table[] = fxUint($order, $next, 4);
    return binary.concat(binary.join($table), binary.join($values));
}

# The 8-byte TIFF header.
func fxHeader(order as string, ifd0 as int) {
    def mark as string init "MM";
    if ($order == "le") {
        $mark = "II";
    }
    return binary.join([
        encoding.encode("utf-8", $mark),
        fxUint($order, 42, 2),
        fxUint($order, $ifd0, 4)
    ]);
}

# A payload with IFD0 only.
func fxPayload(order as string, entries as list of FxEntry) {
    return binary.concat(fxHeader($order, 8), fxIfd($order, 8, $entries, 0));
}

# The caught error as an ExifError; fails the test for anything else.
func fxCaught(e as ExifError) {
    testing.assertEqual($e.kind, "exif");
    testing.assertTrue(strings.startsWith($e.message, "exif: "));
    return $e;
}
