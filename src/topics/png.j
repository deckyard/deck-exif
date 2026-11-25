# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.28.0

# exif - PNG: the eXIf chunk.
# Spliced into exif.j via include - not a standalone module.

/** The largest PNG chunk length. */
def const PNG_MAX_CHUNK as int init 2147483647;

/**
 * Find the `eXIf` chunk of a PNG: walk the chunks from `IHDR` to `IEND`.
 *
 * @param data {bytes} the image, starting with the PNG signature
 * @return {Segment} where the chunk is, and where a new one goes (after `IHDR`)
 * @throws {ExifError} for a truncated or malformed chunk, two `eXIf` chunks, or a wrong `eXIf` CRC
 */
func pngLocate(data as bytes) {
    def n as int init len($data);
    def seg as Segment init noSegment(8);
    def exifType as bytes init ascii("eXIf");
    def endType as bytes init ascii("IEND");
    def pos as int init 8;
    def first as bool init true;
    while (true) {
        need($pos, 8, $n, "PNG chunk");
        def length as int init binary.readUint("be", $data, $pos, 4);
        if ($length > PNG_MAX_CHUNK) {
            failAt("PNG: chunk length " + convert.toString($length) + " is over 2^31-1", $pos);
        }
        need($pos, 12 + $length, $n, "PNG chunk");
        def end as int init $pos + 12 + $length;
        if ($first) {
            if (not hasAt($data, $pos + 4, ascii("IHDR"))) {
                failAt("PNG: the first chunk is not IHDR", $pos + 4);
            }
            $seg.insertAt = $end;
            $first = false;
        }
        if (hasAt($data, $pos + 4, $exifType)) {
            if ($seg.found) {
                failAt("PNG: a second eXIf chunk", $pos);
            }
            if (crc.compute("crc32", $data[$pos + 4..$pos + 8 + $length]) != $data[$end - 4..$end]) {
                failAt("PNG: the eXIf chunk's CRC does not match", $end - 4);
            }
            $seg.found = true;
            $seg.start = $pos;
            $seg.end = $end;
            $seg.payload = $pos + 8;
            $seg.payloadEnd = $pos + 8 + $length;
        }
        if (hasAt($data, $pos + 4, $endType)) {
            return $seg;
        }
        $pos = $end;
    }
}

/**
 * The PNG with its `eXIf` chunk replaced, added or removed.
 *
 * @param data {bytes} the image
 * @param seg {Segment} its `eXIf` chunk, from `pngLocate`
 * @param payload {bytes} the new payload; empty removes the chunk
 * @return {bytes} the new image; every other byte unchanged
 */
func pngReplace(data as bytes, seg as Segment, payload as bytes) {
    if (len($payload) == 0) {
        return cut($data, $seg, binary.make(0));
    }
    def body as bytes init binary.concat(ascii("eXIf"), $payload);
    def chunk as bytes init binary.join([
        uintBytes("be", len($payload), 4),
        $body,
        crc.compute("crc32", $body)
    ]);
    return cut($data, $seg, $chunk);
}
