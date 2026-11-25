# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.28.0

# exif - JPEG: the APP1 "Exif\0\0" segment.
# Spliced into exif.j via include - not a standalone module.

/** The largest EXIF payload one APP1 segment holds: 65535 minus the length field and `Exif\0\0`. */
def const JPEG_MAX_PAYLOAD as int init 65527;

/**
 * Find the EXIF segment of a JPEG: walk the marker segments from `SOI` to
 * the start of scan.
 *
 * @param data {bytes} the image, starting `FF D8`
 * @return {Segment} where the segment is, and where a new one goes
 * @throws {ExifError} for a truncated or malformed header, or two EXIF segments
 */
func jpegLocate(data as bytes) {
    def n as int init len($data);
    def seg as Segment init noSegment(2);
    def exifId as bytes init ascii("Exif");
    $exifId[] = 0;
    $exifId[] = 0;
    def pos as int init 2;
    while (true) {
        if ($pos + 1 >= $n) {
            failAt("truncated JPEG: no start of scan", $pos);
        }
        if ($data[$pos] != 0xFF) {
            failAt("JPEG: expected a marker", $pos);
        }
        def start as int init $pos;
        while ($pos + 1 < $n and $data[$pos + 1] == 0xFF) {
            $pos = $pos + 1;
        }
        if ($pos + 1 >= $n) {
            failAt("truncated JPEG: no start of scan", $pos);
        }
        def marker as int init $data[$pos + 1];
        if ($marker == 0xDA or $marker == 0xD9) {
            return $seg;
        }
        if ($marker == 0x00 or $marker == 0x01 or ($marker >= 0xD0 and $marker <= 0xD8)) {
            failAt(
                "JPEG: marker FF " + strings.upper(io.sprintf("%d|base=16|pad=2|fill=0", $marker)) +
                    " before the start of scan",
                $pos);
        }
        need($pos + 2, 2, $n, "JPEG segment");
        def length as int init binary.readUint("be", $data, $pos + 2, 2);
        if ($length < 2) {
            failAt("JPEG: segment length " + convert.toString($length) + " is below 2", $pos + 2);
        }
        def end as int init $pos + 2 + $length;
        need($pos + 2, $length, $n, "JPEG segment");
        if ($marker == 0xE1 and $length >= 8 and hasAt($data, $pos + 4, $exifId)) {
            if ($seg.found) {
                failAt("JPEG: a second Exif APP1 segment", $pos);
            }
            $seg.found = true;
            $seg.start = $pos;
            $seg.end = $end;
            $seg.payload = $pos + 10;
            $seg.payloadEnd = $end;
        }
        if ($marker == 0xE0 and $start == $seg.insertAt) {
            $seg.insertAt = $end;
        }
        $pos = $end;
    }
}

/**
 * The JPEG with its EXIF segment replaced, added or removed.
 *
 * @param data {bytes} the image
 * @param seg {Segment} its EXIF segment, from `jpegLocate`
 * @param payload {bytes} the new payload; empty removes the segment
 * @return {bytes} the new image; every other byte unchanged
 * @throws {ExifError} when the payload does not fit one APP1 segment
 */
func jpegReplace(data as bytes, seg as Segment, payload as bytes) {
    if (len($payload) == 0) {
        return cut($data, $seg, binary.make(0));
    }
    if (len($payload) > JPEG_MAX_PAYLOAD) {
        fail("an EXIF payload of " + convert.toString(len($payload)) +
            " bytes does not fit a JPEG APP1 segment (" +
            convert.toString(JPEG_MAX_PAYLOAD) + " at most); remove the thumbnail or MakerNote");
    }
    def head as bytes init binary.make(10);
    $head[0] = 0xFF;
    $head[1] = 0xE1;
    $head[2] = ((len($payload) + 8) >> 8) & 0xff;
    $head[3] = (len($payload) + 8) & 0xff;
    $head[4] = 0x45;
    $head[5] = 0x78;
    $head[6] = 0x69;
    $head[7] = 0x66;
    return cut($data, $seg, binary.concat($head, $payload));
}
