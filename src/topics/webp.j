# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.27.0

# exif - WebP: the EXIF chunk of the extended (VP8X) format.
# Spliced into exif.j via include - not a standalone module.

/** The `VP8X` flag bit that says the file has an `EXIF` chunk. */
def const WEBP_EXIF_FLAG as int init 0x08;

/** The `VP8X` flag bit that says the image has alpha. */
def const WEBP_ALPHA_FLAG as int init 0x10;

/**
 * Find the `EXIF` chunk of a WebP: walk the RIFF chunks.
 *
 * @param data {bytes} the image, starting `RIFF....WEBP`
 * @return {Segment} where the chunk is; `insertAt` is the first `XMP ` chunk or the end; `extended` tells a `VP8X` file
 * @throws {ExifError} for a malformed RIFF structure, two `EXIF` chunks, or a chunk and `VP8X` flag that disagree
 */
func webpLocate(data as bytes) {
    def n as int init len($data);
    need(4, 4, $n, "RIFF header");
    def riff as int init binary.readUint("le", $data, 4, 4);
    if ($riff + 8 != $n) {
        failAt(
            "WebP: the RIFF size " + convert.toString($riff) + " does not match the file's " +
                convert.toString($n) + " bytes",
            4);
    }
    def seg as Segment init noSegment($n);
    def exifType as bytes init ascii("EXIF");
    def xmpType as bytes init ascii("XMP ");
    need(12, 8, $n, "WebP chunk");
    if (hasAt($data, 12, ascii("VP8X"))) {
        $seg.extended = true;
        # the flags byte and canvas size are rewritten in place, so they must be the chunk's own
        if (binary.readUint("le", $data, 16, 4) < 10) {
            failAt("WebP: the VP8X chunk is shorter than 10 bytes", 16);
        }
    } elseif (not hasAt($data, 12, ascii("VP8 ")) and not hasAt($data, 12, ascii("VP8L"))) {
        failAt("WebP: the first chunk is none of VP8, VP8L, VP8X", 12);
    }
    def pos as int init 12;
    while ($pos < $n) {
        need($pos, 8, $n, "WebP chunk");
        def size as int init binary.readUint("le", $data, $pos + 4, 4);
        def end as int init $pos + 8 + $size + ($size % 2);
        need($pos + 8, $size + ($size % 2), $n, "WebP chunk");
        if (hasAt($data, $pos, $exifType)) {
            if ($seg.found) {
                failAt("WebP: a second EXIF chunk", $pos);
            }
            $seg.found = true;
            $seg.start = $pos;
            $seg.end = $end;
            $seg.payload = $pos + 8;
            $seg.payloadEnd = $pos + 8 + $size;
        }
        if (hasAt($data, $pos, $xmpType) and $seg.insertAt == $n) {
            $seg.insertAt = $pos;
        }
        $pos = $end;
    }
    if (not $seg.extended) {
        if ($seg.found) {
            failAt("WebP: an EXIF chunk in a simple-format file (no VP8X)", $seg.start);
        }
        return $seg;
    }
    need(20, 10, $n, "VP8X chunk");
    def flagged as bool init ($data[20] & WEBP_EXIF_FLAG) != 0;
    if ($flagged and not $seg.found) {
        failAt("WebP: the VP8X EXIF flag is set but there is no EXIF chunk", 20);
    }
    if ($seg.found and not $flagged) {
        failAt("WebP: an EXIF chunk without the VP8X EXIF flag", $seg.start);
    }
    return $seg;
}

/**
 * The `VP8X` chunk for a simple-format file: its canvas size and alpha from
 * the bitstream header, and the EXIF flag.
 *
 * @param data {bytes} the simple-format image
 * @return {bytes} the 18-byte chunk
 * @throws {ExifError} when the `VP8 ` or `VP8L` header is malformed
 */
func vp8xFor(data as bytes) {
    def n as int init len($data);
    def at as int init 20;
    def width as int init 0;
    def height as int init 0;
    def flags as int init WEBP_EXIF_FLAG;
    if (hasAt($data, 12, ascii("VP8L"))) {
        need($at, 5, $n, "VP8L header");
        if ($data[$at] != 0x2F) {
            failAt("WebP: bad VP8L signature", $at);
        }
        def bits as int init binary.readUint("le", $data, $at + 1, 4);
        $width = ($bits & 0x3FFF) + 1;
        $height = (($bits >> 14) & 0x3FFF) + 1;
        if ((($bits >> 28) & 1) == 1) {
            $flags = $flags | WEBP_ALPHA_FLAG;
        }
    } else {
        need($at, 10, $n, "VP8 header");
        if ($data[$at + 3] != 0x9D or $data[$at + 4] != 0x01 or $data[$at + 5] != 0x2A) {
            failAt("WebP: bad VP8 start code", $at + 3);
        }
        $width = binary.readUint("le", $data, $at + 6, 2) & 0x3FFF;
        $height = binary.readUint("le", $data, $at + 8, 2) & 0x3FFF;
    }
    def chunk as bytes init ascii("VP8X");
    return binary.join([
        $chunk,
        uintBytes("le", 10, 4),
        uintBytes("le", $flags, 4),
        uintBytes("le", $width - 1, 3),
        uintBytes("le", $height - 1, 3)
    ]);
}

/**
 * The WebP with its `EXIF` chunk replaced, added or removed, the `VP8X`
 * flag and the RIFF size updated. A simple-format file gets a `VP8X` chunk.
 *
 * @param data {bytes} the image
 * @param seg {Segment} its `EXIF` chunk, from `webpLocate`
 * @param payload {bytes} the new payload; empty removes the chunk
 * @return {bytes} the new image; every other byte unchanged
 * @throws {ExifError} when a simple-format bitstream header is malformed
 */
func webpReplace(data as bytes, seg as Segment, payload as bytes) {
    if (len($payload) == 0 and not $seg.found) {
        return $data;
    }
    def chunk as bytes;
    if (len($payload) > 0) {
        def parts as list of bytes init [
            ascii("EXIF"),
            uintBytes("le", len($payload), 4),
            $payload
        ];
        if (len($payload) % 2 == 1) {
            $parts[] = binary.make(1);
        }
        $chunk = binary.join($parts);
    }
    def out as list of bytes init [ascii("RIFF"), binary.make(4), ascii("WEBP")];
    if (not $seg.extended) {
        $out[] = vp8xFor($data);
        $out[] = $data[12..len($data)];
        $out[] = $chunk;
    } else {
        def flags as bytes init binary.make(1);
        $flags[0] = $data[20] & (0xFF ^ WEBP_EXIF_FLAG);
        if (len($payload) > 0) {
            $flags[0] = $flags[0] | WEBP_EXIF_FLAG;
        }
        $out[] = $data[12..20];
        $out[] = $flags;
        def from as int init $seg.insertAt;
        def to2 as int init $seg.insertAt;
        if ($seg.found) {
            $from = $seg.start;
            $to2 = $seg.end;
        }
        $out[] = $data[21..$from];
        $out[] = $chunk;
        $out[] = $data[$to2..len($data)];
    }
    def joined as bytes init binary.join($out);
    def size as bytes init uintBytes("le", len($joined) - 8, 4);
    for (def i in 0..4) {
        $joined[4 + $i] = $size[$i];
    }
    return $joined;
}
