# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.28.0

# exif - the TIFF structure: parse a payload into an Exif, render one back.
# Spliced into exif.j via include - not a standalone module.

/**
 * Where a payload lies in the input, and how to read it.
 *
 * @field base {int} the offset of the TIFF header; IFD offsets count from here
 * @field end {int} the first byte past the payload
 * @field order {string} `"le"` or `"be"`
 * @field caps {Options} the caps in force
 * @field bytesLeft {int} value bytes the IFDs not yet read may still decode
 * @field numbersLeft {int} numbers the IFDs not yet read may still decode
 */
def struct Payload {
    base as int,
    end as int,
    order as string,
    caps as Options,
    bytesLeft as int,
    numbersLeft as int
};

/**
 * What one IFD held besides its entries.
 *
 * @field entries {list of Entry} the entries, without the structural tags
 * @field next {int} the next-IFD offset, 0 for none
 * @field pointers {map of int to int} structural tag to its value (IFD pointers, thumbnail offset and length)
 * @field bytesUsed {int} the value bytes its entries decoded
 * @field numbersUsed {int} the numbers its entries decoded
 */
def struct IfdRead {
    entries as list of Entry,
    next as int,
    pointers as map of int to int,
    bytesUsed as int,
    numbersUsed as int
};

/**
 * An unsigned integer of the payload, bounds-checked.
 *
 * @param data {bytes} the input
 * @param p {Payload} the payload
 * @param at {int} the absolute offset
 * @param size {int} 2 or 4
 * @param what {string} what is read, for the message
 * @return {int} the value
 * @throws {ExifError} when the bytes run past the payload
 */
func uintAt(data as bytes, p as Payload, at as int, size as int, what as string) {
    need($at, $size, $p.end, $what);
    return binary.readUint($p.order, $data, $at, $size);
}

/**
 * Read the EXIF payload that sits at `[base, end)` of `data`.
 *
 * @param data {bytes} the input, read in place
 * @param base {int} the offset of the TIFF header
 * @param end {int} the first byte past the payload
 * @param options {Options} the caller's caps
 * @return {Exif} the metadata
 * @throws {ExifError} for malformed data, offsets counted in `data`
 * @throws {Error} kind "limit" when a cap is reached
 */
func parseAt(data as bytes, base as int, end as int, options as Options) {
    def caps as Options init capsOf($options);
    if ($end - $base > $caps.maxBytes) {
        failLimit("EXIF payload of " + convert.toString($end - $base) + " bytes is over the " +
            convert.toString($caps.maxBytes) + "-byte cap");
    }
    need($base, 8, $end, "TIFF header");
    def order as string init "";
    if ($data[$base] == 0x49 and $data[$base + 1] == 0x49) {
        $order = "le";
    } elseif ($data[$base] == 0x4D and $data[$base + 1] == 0x4D) {
        $order = "be";
    } else {
        failAt("bad TIFF header: byte order is neither II nor MM", $base);
    }
    def p as Payload init Payload{
        base: $base,
        end: $end,
        order: $order,
        caps: $caps,
        bytesLeft: $caps.maxBytes,
        numbersLeft: MAX_NUMBERS
    };
    if (binary.readUint($order, $data, $base + 2, 2) != 42) {
        failAt("bad TIFF header: the magic number is not 42", $base + 2);
    }
    def seen as list of int init [];
    def out as Exif init empty($order);

    def ifd0 as IfdRead init readIfd(
        $data,
        $p,
        IFD0,
        binary.readUint($order, $data, $base + 4, 4),
        $seen);
    for (def e in $ifd0.entries) {
        $out.entries[] = $e;
    }
    $seen = seenAfter($seen, $ifd0);
    $p = spent($p, $ifd0);

    if (maps.has($ifd0.pointers, TAG_EXIF_POINTER)) {
        def sub as IfdRead init readSub(
            $data,
            $p,
            IFD_EXIF,
            $ifd0.pointers[TAG_EXIF_POINTER],
            $seen);
        $seen = seenAfter($seen, $sub);
        $p = spent($p, $sub);
        for (def e in $sub.entries) {
            $out.entries[] = $e;
        }
        if (maps.has($sub.pointers, TAG_INTEROP_POINTER)) {
            def inter as IfdRead init readSub(
                $data,
                $p,
                IFD_INTEROP,
                $sub.pointers[TAG_INTEROP_POINTER],
                $seen);
            $seen = seenAfter($seen, $inter);
            $p = spent($p, $inter);
            for (def e in $inter.entries) {
                $out.entries[] = $e;
            }
        }
    }
    if (maps.has($ifd0.pointers, TAG_GPS_POINTER)) {
        def gpsIfd as IfdRead init readSub(
            $data,
            $p,
            IFD_GPS,
            $ifd0.pointers[TAG_GPS_POINTER],
            $seen);
        $seen = seenAfter($seen, $gpsIfd);
        $p = spent($p, $gpsIfd);
        for (def e in $gpsIfd.entries) {
            $out.entries[] = $e;
        }
    }
    if ($ifd0.next != 0) {
        def ifd1 as IfdRead init readIfd($data, $p, IFD1, $ifd0.next, $seen);
        if ($ifd1.next != 0) {
            failAt("IFD1 links to a third IFD, which EXIF does not have", $base + $ifd0.next);
        }
        for (def e in $ifd1.entries) {
            $out.entries[] = $e;
        }
        $out.thumbnail = thumbnailOf($data, $p, $ifd1);
    }
    return $out;
}

/**
 * The visited list after an IFD was read, with that IFD's offset added.
 *
 * `readIfd` gets `seen` as a copy (value semantics) and reports its own
 * offset as `pointers[-1]`; the caller records it here.
 *
 * @param seen {list of int} offsets read so far
 * @param ifd {IfdRead} the IFD just read
 * @return {list of int} the list with the IFD's own offset
 */
func seenAfter(seen as list of int, ifd as IfdRead) {
    if (maps.has($ifd.pointers, -1)) {
        $seen[] = $ifd.pointers[-1];
    }
    return $seen;
}

/**
 * The payload with an IFD's decoded values taken off its budgets.
 *
 * @param p {Payload} the payload
 * @param ifd {IfdRead} the IFD just read
 * @return {Payload} the payload with smaller budgets
 */
func spent(p as Payload, ifd as IfdRead) {
    $p.bytesLeft = $p.bytesLeft - $ifd.bytesUsed;
    $p.numbersLeft = $p.numbersLeft - $ifd.numbersUsed;
    return $p;
}

/**
 * Read a sub-IFD (Exif, GPS, Interop), whose next-IFD offset must be 0.
 *
 * @param data {bytes} the input
 * @param p {Payload} the payload
 * @param ifd {string} its name
 * @param offset {int} its offset from the TIFF header
 * @param seen {list of int} IFD offsets already read
 * @return {IfdRead} the IFD
 * @throws {ExifError} for a malformed IFD or a next-IFD link
 */
func readSub(data as bytes, p as Payload, ifd as string, offset as int, seen as list of int) {
    def r as IfdRead init readIfd($data, $p, $ifd, $offset, $seen);
    if ($r.next != 0) {
        failAt("the " + $ifd + " IFD links to a next IFD", $p.base + $offset);
    }
    return $r;
}

/**
 * Read one IFD.
 *
 * @param data {bytes} the input
 * @param p {Payload} the payload
 * @param ifd {string} its name
 * @param offset {int} its offset from the TIFF header
 * @param seen {list of int} IFD offsets already read
 * @return {IfdRead} the entries, next link and structural values; `pointers[-1]` is the IFD's own offset
 * @throws {ExifError} for a malformed IFD
 * @throws {Error} kind "limit" when a cap is reached
 */
func readIfd(data as bytes, p as Payload, ifd as string, offset as int, seen as list of int) {
    def at as int init $p.base + $offset;
    if ($offset < 8 or $at >= $p.end) {
        failAt(
            "the " + $ifd + " IFD offset " + convert.toString($offset) + " is outside the payload",
            $at);
    }
    if (lists.contains($seen, $offset)) {
        failAt(
            "the " + $ifd + " IFD offset " + convert.toString($offset) +
                " points at an IFD already read (a loop)",
            $at);
    }
    def n as int init uintAt($data, $p, $at, 2, $ifd + " IFD");
    if ($n > $p.caps.maxEntries) {
        failLimit("the " + $ifd + " IFD has " + convert.toString($n) +
            " entries, over the cap of " +
            convert.toString($p.caps.maxEntries));
    }
    need($at, 2 + 12 * $n + 4, $p.end, $ifd + " IFD");
    def out as IfdRead init IfdRead{
        entries: [],
        next: 0,
        pointers: {-1: $offset},
        bytesUsed: 0,
        numbersUsed: 0
    };
    def tags as map of int to bool init {};
    for (def i in 0..$n) {
        def e as int init $at + 2 + 12 * $i;
        def tag as int init binary.readUint($p.order, $data, $e, 2);
        def type as int init binary.readUint($p.order, $data, $e + 2, 2);
        def count as int init binary.readUint($p.order, $data, $e + 4, 4);
        if (maps.has($tags, $tag)) {
            failAt(label($ifd, $tag) + " appears twice", $e);
        }
        $tags[$tag] = true;
        def size as int init typeSize($type);
        if ($size == 0) {
            failAt(
                label($ifd, $tag) + " has unknown field type " + convert.toString($type),
                $e + 2);
        }
        def bytesNeeded as int init $size * $count;
        if ($bytesNeeded > $p.caps.maxValueBytes) {
            failLimit(label($ifd, $tag) + " holds " + convert.toString($bytesNeeded) +
                " bytes, over the cap of " +
                convert.toString($p.caps.maxValueBytes));
        }
        def valueAt as int init $e + 8;
        if ($bytesNeeded > 4) {
            def rel as int init binary.readUint($p.order, $data, $e + 8, 4);
            $valueAt = $p.base + $rel;
            if ($rel < 8 or $valueAt + $bytesNeeded > $p.end) {
                failAt(
                    label($ifd, $tag) + ": value at offset " + convert.toString($rel) + " (" +
                        convert.toString($bytesNeeded) + " bytes) runs past the payload",
                    $e + 8);
            }
        }
        if (isPointerTag($tag)) {
            if (not isStructural($ifd, $tag)) {
                failAt(label($ifd, $tag) + " is a pointer tag outside its IFD", $e);
            }
            if ($type != TYPE_LONG or $count != 1) {
                failAt(label($ifd, $tag) + " must be one LONG", $e + 2);
            }
            $out.pointers[$tag] = binary.readUint($p.order, $data, $valueAt, 4);
        } else {
            # values may share bytes, so the payload cap alone does not bound what is decoded
            $out.bytesUsed = $out.bytesUsed + $bytesNeeded;
            if ($out.bytesUsed > $p.bytesLeft) {
                failLimit("the values decode to more than the cap of " +
                    convert.toString($p.caps.maxBytes) + " bytes");
            }
            $out.numbersUsed = $out.numbersUsed + numbersOf($type, $count);
            if ($out.numbersUsed > $p.numbersLeft) {
                failLimit("the values hold more than " + convert.toString(MAX_NUMBERS) +
                    " numbers");
            }
            def value as Value init decodeValue($data, $p.order, $type, $count, $valueAt);
            $out.entries[] = Entry{ifd: $ifd, tag: $tag, type: $type, count: $count, value: $value};
        }
    }
    $out.next = binary.readUint($p.order, $data, $at + 2 + 12 * $n, 4);
    $out.entries = sortedEntries($out.entries);
    return $out;
}

/**
 * How many numbers a value decodes to; text and raw bytes decode to none.
 *
 * @param type {int} the field type
 * @param count {int} the count
 * @return {int} `count`, twice that for rationals, 0 for `ASCII` and `UNDEFINED`
 */
func numbersOf(type as int, count as int) {
    if ($type == TYPE_ASCII or $type == TYPE_UNDEFINED) {
        return 0;
    }
    if ($type == TYPE_RATIONAL or $type == TYPE_SRATIONAL) {
        return 2 * $count;
    }
    return $count;
}

/**
 * Entries of one IFD sorted by tag, the order the writer uses, so a read
 * after a write gives the same list.
 *
 * @param entries {list of Entry} the entries of one IFD, tags unique
 * @return {list of Entry} the same entries in ascending tag order
 */
func sortedEntries(entries as list of Entry) {
    def byTag as map of int to int init {};
    def tags as list of int init [];
    for (def i in 0..len($entries)) {
        $byTag[$entries[$i].tag] = $i;
        $tags[] = $entries[$i].tag;
    }
    def out as list of Entry init [];
    for (def t in lists.sort($tags)) {
        $out[] = $entries[$byTag[$t]];
    }
    return $out;
}

/**
 * Whether a tag number is one of the structural tags, in any IFD.
 *
 * @param tag {int} the tag number
 * @return {bool} true for the three IFD pointers and the thumbnail location
 */
func isPointerTag(tag as int) {
    return $tag == TAG_EXIF_POINTER or $tag == TAG_GPS_POINTER or $tag == TAG_INTEROP_POINTER or
        $tag == TAG_THUMB_OFFSET or $tag == TAG_THUMB_LENGTH;
}

/**
 * The thumbnail bytes IFD1 points at.
 *
 * @param data {bytes} the input
 * @param p {Payload} the payload
 * @param ifd1 {IfdRead} IFD1 as read
 * @return {bytes} the JPEG, empty when IFD1 has no thumbnail location
 * @throws {ExifError} when only one of offset and length is there, or the bytes run past the payload
 */
func thumbnailOf(data as bytes, p as Payload, ifd1 as IfdRead) {
    def none as bytes;
    def hasOffset as bool init maps.has($ifd1.pointers, TAG_THUMB_OFFSET);
    def hasLength as bool init maps.has($ifd1.pointers, TAG_THUMB_LENGTH);
    if (not $hasOffset and not $hasLength) {
        return $none;
    }
    if ($hasOffset != $hasLength) {
        failAt("IFD1 has only one of the thumbnail's offset and length", $p.base);
    }
    def offset as int init $ifd1.pointers[TAG_THUMB_OFFSET];
    def length as int init $ifd1.pointers[TAG_THUMB_LENGTH];
    if ($length > $p.caps.maxValueBytes) {
        failLimit("the thumbnail of " + convert.toString($length) + " bytes is over the cap of " +
            convert.toString($p.caps.maxValueBytes));
    }
    def at as int init $p.base + $offset;
    if ($offset < 8 or $at + $length > $p.end) {
        failAt(
            "the thumbnail at offset " + convert.toString($offset) + " (" +
                convert.toString($length) +
                " bytes) runs past the payload",
            $at);
    }
    return $data[$at..$at + $length];
}

/**
 * Integers read as signed, made unsigned.
 *
 * @param values {list of int} signed values
 * @param modulus {int} 256, 65536 or 2^32
 * @return {list of int} the values with `modulus` added to each negative one
 */
func unsigned(values as list of int, modulus as int) {
    def out as list of int init [];
    for (def v in $values) {
        if ($v < 0) {
            $out[] = $v + $modulus;
        } else {
            $out[] = $v;
        }
    }
    return $out;
}

/**
 * Decode one value.
 *
 * @param data {bytes} the input
 * @param order {string} `"le"` or `"be"`
 * @param type {int} the field type, 1-12
 * @param count {int} the number of values
 * @param at {int} the absolute offset of the first byte
 * @return {Value} the value
 * @throws {ExifError} for a NaN or infinite float
 */
func decodeValue(data as bytes, order as string, type as int, count as int, at as int) {
    match ($type) {
        when 1 {
            return Value.Ints{
                values: unsigned(binary.readInts($order, $data, $at, $count, 1), 256)
            };
        }
        when 2 { return Value.Ascii{data: $data[$at..$at + $count]}; }
        when 3 {
            return Value.Ints{
                values: unsigned(binary.readInts($order, $data, $at, $count, 2), 65536)
            };
        }
        when 4 {
            return Value.Ints{
                values: unsigned(binary.readInts($order, $data, $at, $count, 4), UINT32_MAX + 1)
            };
        }
        when 5, 10 {
            def parts as list of int init binary.readInts($order, $data, $at, 2 * $count, 4);
            if ($type == 5) {
                $parts = unsigned($parts, UINT32_MAX + 1);
            }
            def rs as list of Rational init [];
            for (def i in 0..$count) {
                $rs[] = Rational{num: $parts[2 * $i], den: $parts[2 * $i + 1]};
            }
            return Value.Rationals{values: $rs};
        }
        when 6 { return Value.Ints{values: binary.readInts($order, $data, $at, $count, 1)}; }
        when 7 { return Value.Undefined{data: $data[$at..$at + $count]}; }
        when 8 { return Value.Ints{values: binary.readInts($order, $data, $at, $count, 2)}; }
        when 9 { return Value.Ints{values: binary.readInts($order, $data, $at, $count, 4)}; }
        else {
            try {
                return Value.Floats{
                    values: binary.readFloats($order, $data, $at, $count, typeSize($type))
                };
            } catch (e) {
                failAt("a NaN or infinite float", $at);
            }
        }
    }
}

/**
 * Parse a bare EXIF payload: the TIFF structure that starts `II*\0` or
 * `MM\0*`, as a JPEG's APP1 segment holds it after `Exif\0\0`.
 *
 * @param payload {bytes} the payload
 * @return {Exif} the metadata
 * @throws {ExifError} kind "exif" for malformed data, `offset` counted in the payload
 * @throws {Error} kind "limit" when a default cap is reached
 */
export func parse(payload as bytes) {
    return parseAt(
        $payload,
        0,
        len($payload),
        Options{maxBytes: 0, maxEntries: 0, maxValueBytes: 0});
}

/**
 * `parse` with lowered caps.
 *
 * @param payload {bytes} the payload
 * @param options {Options} the caps; a zero field keeps the default
 * @return {Exif} the metadata
 * @throws {ExifError} kind "exif" for malformed data or a bad option
 * @throws {Error} kind "limit" when a cap is reached
 */
export func parseWith(payload as bytes, options as Options) {
    return parseAt($payload, 0, len($payload), $options);
}

/**
 * One entry ready to write.
 *
 * @field tag {int} the tag number
 * @field type {int} the field type
 * @field count {int} the count
 * @field data {bytes} the encoded value
 */
def struct Slot {
    tag as int,
    type as int,
    count as int,
    data as bytes
};

/**
 * Encode a value in a byte order.
 *
 * @param e {Entry} a checked entry
 * @param order {string} `"le"` or `"be"`
 * @return {bytes} `count` times the type's size bytes
 * @throws {ExifError} for a float too large for `FLOAT`
 */
func encodeValue(e as Entry, order as string) {
    def size as int init typeSize($e.type);
    def out as bytes;
    match ($e.value) {
        when Ascii(p) { return $p.data; }
        when Undefined(p) { return $p.data; }
        when Ints(p) {
            if ($size == 1) {
                for (def v in $p.values) {
                    $out[] = $v & 0xff;
                }
                return $out;
            }
            def parts as list of bytes init [];
            for (def v in $p.values) {
                $parts[] = uintBytes($order, $v, $size);
            }
            return binary.join($parts);
        }
        when Rationals(p) {
            def parts as list of bytes init [];
            for (def r in $p.values) {
                $parts[] = uintBytes($order, $r.num, 4);
                $parts[] = uintBytes($order, $r.den, 4);
            }
            return binary.join($parts);
        }
        when Floats(p) {
            def parts as list of bytes init [];
            for (def f in $p.values) {
                $parts[] = uintBytes($order, floatBits($f, $size), $size);
            }
            return binary.join($parts);
        }
    }
}

/**
 * Serialise the metadata into an EXIF payload: the TIFF header, IFD0, the
 * Exif, Interop, GPS and IFD1 directories that have entries, each with its
 * values, then the thumbnail. Offsets and pointers are computed; entries are
 * sorted by tag; every IFD and value starts at an even offset.
 *
 * @param x {Exif} the metadata
 * @return {bytes} the payload, starting `II*\0` or `MM\0*`
 * @throws {ExifError} for an entry that does not check out, a tag twice in one IFD, or an unknown byte order
 * @throws {Error} kind "limit" for a value, thumbnail, IFD or payload over a default cap of `parse`
 */
export func render(x as Exif) {
    checkOrder($x.order);
    def order as string init $x.order;
    def groups as list of list of Slot init slotsOf($x);
    def hasThumb as bool init len($x.thumbnail) > 0;
    def present as list of bool init [
        true,
        len($groups[1]) > 0 or len($groups[2]) > 0,
        len($groups[2]) > 0,
        len($groups[3]) > 0,
        len($groups[4]) > 0 or $hasThumb
    ];
    # the pointer slots; their values are filled in once the layout is known
    def zero as bytes init binary.make(4);
    if ($present[1]) {
        $groups[0][] = Slot{tag: TAG_EXIF_POINTER, type: TYPE_LONG, count: 1, data: $zero};
    }
    if ($present[3]) {
        $groups[0][] = Slot{tag: TAG_GPS_POINTER, type: TYPE_LONG, count: 1, data: $zero};
    }
    if ($present[2]) {
        $groups[1][] = Slot{tag: TAG_INTEROP_POINTER, type: TYPE_LONG, count: 1, data: $zero};
    }
    if ($hasThumb) {
        $groups[4][] = Slot{tag: TAG_THUMB_OFFSET, type: TYPE_LONG, count: 1, data: $zero};
        $groups[4][] = Slot{
            tag: TAG_THUMB_LENGTH,
            type: TYPE_LONG,
            count: 1,
            data: uintBytes($order, len($x.thumbnail), 4)
        };
    }
    if (len($x.thumbnail) > MAX_VALUE_BYTES) {
        failLimit("the thumbnail of " + convert.toString(len($x.thumbnail)) +
            " bytes is over the cap of " + convert.toString(MAX_VALUE_BYTES));
    }
    # where each IFD goes, and after them the thumbnail
    def offsets as list of int init [0, 0, 0, 0, 0];
    def pos as int init 8;
    for (def g in 0..5) {
        if ($present[$g]) {
            if (len($groups[$g]) > MAX_ENTRIES) {
                failLimit("the " + IFDS[$g] + " IFD would have " +
                    convert.toString(len($groups[$g])) + " entries, over the cap of " +
                    convert.toString(MAX_ENTRIES));
            }
            $offsets[$g] = $pos;
            $pos = $pos + ifdSize($groups[$g]);
        }
    }
    if ($pos + len($x.thumbnail) > MAX_BYTES) {
        failLimit("the EXIF payload would be " + convert.toString($pos + len($x.thumbnail)) +
            " bytes, over the cap of " + convert.toString(MAX_BYTES));
    }
    def out as list of bytes init [];
    if ($order == "le") {
        $out[] = ascii("II");
    } else {
        $out[] = ascii("MM");
    }
    $out[] = uintBytes($order, 42, 2);
    $out[] = uintBytes($order, 8, 4);
    for (def g in 0..5) {
        if ($present[$g]) {
            def next as int init 0;
            if ($g == 0 and $present[4]) {
                $next = $offsets[4];
            }
            $out[] = ifdBytes(
                sortedSlots($groups[$g]),
                $order,
                $offsets,
                $pos,
                $offsets[$g],
                $next);
        }
    }
    $out[] = $x.thumbnail;
    return binary.join($out);
}

/**
 * The entries as slots, grouped by IFD in layout order, each checked.
 *
 * @param x {Exif} the metadata
 * @return {list of list of Slot} five groups: IFD0, Exif, Interop, GPS, IFD1
 * @throws {ExifError} for an entry that does not check out or a tag twice in one IFD
 * @throws {Error} kind "limit" for a value over `MAX_VALUE_BYTES`, or more than 65,536 numbers
 */
func slotsOf(x as Exif) {
    def groups as list of list of Slot init [[], [], [], [], []];
    def seen as map of string to bool init {};
    def numbers as int init 0;
    for (def e in $x.entries) {
        checkEntry($e);
        $numbers = $numbers + numbersOf($e.type, $e.count);
        if ($numbers > MAX_NUMBERS) {
            failLimit("the values hold more than " + convert.toString(MAX_NUMBERS) + " numbers");
        }
        def key as string init $e.ifd + ":" + convert.toString($e.tag);
        if (maps.has($seen, $key)) {
            fail(label($e.ifd, $e.tag) + " appears twice");
        }
        $seen[$key] = true;
        def data as bytes init encodeValue($e, $x.order);
        if (len($data) > MAX_VALUE_BYTES) {
            failLimit(label($e.ifd, $e.tag) + " holds " + convert.toString(len($data)) +
                " bytes, over the cap of " + convert.toString(MAX_VALUE_BYTES));
        }
        $groups[lists.indexOf(IFDS, $e.ifd)][] = Slot{
            tag: $e.tag,
            type: $e.type,
            count: $e.count,
            data: $data
        };
    }
    return $groups;
}

/**
 * The bytes an IFD takes: its table and its out-of-line values, each value
 * padded to an even length.
 *
 * @param slots {list of Slot} the IFD's slots, pointers included
 * @return {int} the size, always even
 */
func ifdSize(slots as list of Slot) {
    def size as int init 2 + 12 * len($slots) + 4;
    for (def s in $slots) {
        if (len($s.data) > 4) {
            $size = $size + len($s.data) + len($s.data) % 2;
        }
    }
    return $size;
}

/**
 * One IFD: the entry count, the entries, the next-IFD offset, then the
 * values that do not fit in an entry.
 *
 * @param slots {list of Slot} the slots, sorted by tag
 * @param order {string} the byte order
 * @param offsets {list of int} each IFD's offset, in layout order; this IFD's own among them
 * @param thumbAt {int} the thumbnail's offset
 * @param at {int} this IFD's offset
 * @param next {int} the next-IFD offset, 0 for none
 * @return {bytes} `ifdSize(slots)` bytes
 */
func ifdBytes(
    slots as list of Slot,
    order as string,
    offsets as list of int,
    thumbAt as int,
    at as int,
    next as int) {
    def table as list of bytes init [uintBytes($order, len($slots), 2)];
    def values as list of bytes init [];
    def valueAt as int init $at + 2 + 12 * len($slots) + 4;
    for (def s in $slots) {
        def data as bytes init pointerValue($s, $order, $offsets, $thumbAt);
        $table[] = uintBytes($order, $s.tag, 2);
        $table[] = uintBytes($order, $s.type, 2);
        $table[] = uintBytes($order, $s.count, 4);
        if (len($data) > 4) {
            $table[] = uintBytes($order, $valueAt, 4);
            $values[] = $data;
            $valueAt = $valueAt + len($data);
            if (len($data) % 2 == 1) {
                $values[] = binary.make(1);
                $valueAt = $valueAt + 1;
            }
        } else {
            $table[] = $data;
            $table[] = binary.make(4 - len($data));
        }
    }
    $table[] = uintBytes($order, $next, 4);
    return binary.join([binary.join($table), binary.join($values)]);
}

/**
 * The value bytes of a slot, with the pointer slots filled in.
 *
 * @param s {Slot} the slot
 * @param order {string} the byte order
 * @param offsets {list of int} each IFD's offset, in layout order
 * @param thumbAt {int} the thumbnail's offset
 * @return {bytes} the value bytes
 */
func pointerValue(s as Slot, order as string, offsets as list of int, thumbAt as int) {
    match ($s.tag) {
        when TAG_EXIF_POINTER { return uintBytes($order, $offsets[1], 4); }
        when TAG_INTEROP_POINTER { return uintBytes($order, $offsets[2], 4); }
        when TAG_GPS_POINTER { return uintBytes($order, $offsets[3], 4); }
        when TAG_THUMB_OFFSET { return uintBytes($order, $thumbAt, 4); }
        else { return $s.data; }
    }
}

/**
 * Slots sorted by tag number.
 *
 * @param slots {list of Slot} the slots of one IFD, tags unique
 * @return {list of Slot} the same slots in ascending tag order
 */
func sortedSlots(slots as list of Slot) {
    def byTag as map of int to int init {};
    def tags as list of int init [];
    for (def i in 0..len($slots)) {
        $byTag[$slots[$i].tag] = $i;
        $tags[] = $slots[$i].tag;
    }
    def out as list of Slot init [];
    for (def t in lists.sort($tags)) {
        $out[] = $slots[$byTag[$t]];
    }
    return $out;
}
