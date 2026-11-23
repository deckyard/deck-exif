# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.27.0

# exif - the model (Exif, Entry, Value), entry lookup and the setters.
# Spliced into exif.j via include - not a standalone module.

/**
 * A fraction, the value of a `RATIONAL` or `SRATIONAL` field.
 *
 * @field num {int} the numerator
 * @field den {int} the denominator; 0 is stored as read (some cameras write 0/0 for "unknown")
 */
export def struct Rational {
    num as int,
    den as int
};

/**
 * The value of an entry; the entry's `type` says which field type it is
 * written as. `match` on it to read the payload, or use `ints`, `text`,
 * `rationals`, `floats` and `raw`.
 *
 * - `Ints` - `BYTE`, `SHORT`, `LONG`, `SBYTE`, `SSHORT`, `SLONG`
 * - `Ascii` - `ASCII`: the bytes as stored, terminating NUL included
 * - `Undefined` - `UNDEFINED`: the bytes as stored
 * - `Rationals` - `RATIONAL`, `SRATIONAL`
 * - `Floats` - `FLOAT`, `DOUBLE`
 */
export def enum Value {
    Ints{values as list of int},
    Ascii{data as bytes},
    Undefined{data as bytes},
    Rationals{values as list of Rational},
    Floats{values as list of float}
};

/**
 * One tag in one IFD.
 *
 * @field ifd {string} `IFD0`, `IFD_EXIF`, `IFD_GPS`, `IFD_INTEROP` or `IFD1`
 * @field tag {int} the tag number
 * @field type {int} the field type, `TYPE_BYTE` (1) to `TYPE_DOUBLE` (12)
 * @field count {int} the number of values (bytes for `ASCII` and `UNDEFINED`)
 * @field value {Value} the value
 */
export def struct Entry {
    ifd as string,
    tag as int,
    type as int,
    count as int,
    value as Value
};

/**
 * The EXIF metadata of one image.
 *
 * @field order {string} the byte order, `"le"` (`II`) or `"be"` (`MM`); `write` keeps it
 * @field entries {list of Entry} every tag of every IFD, without the IFD pointers and thumbnail location, which the writer computes
 * @field thumbnail {bytes} the JPEG thumbnail of IFD1, empty when there is none
 */
export def struct Exif {
    order as string,
    entries as list of Entry,
    thumbnail as bytes
};

/**
 * An `Exif` without entries.
 *
 * @param order {string} `"le"` or `"be"`
 * @return {Exif} no entries, no thumbnail
 * @throws {ExifError} for another byte order
 * @example
 *   def e as exif.Exif init exif.setText(exif.empty("le"), "Artist", "Ada");
 */
export func empty(order as string) {
    checkOrder($order);
    def none as bytes;
    return Exif{order: $order, entries: [], thumbnail: $none};
}

/**
 * Check a byte order name.
 *
 * @param order {string} the name
 * @throws {ExifError} unless it is `"le"` or `"be"`
 */
func checkOrder(order as string) {
    if ($order != "le" and $order != "be") {
        fail("byte order must be \"le\" or \"be\", got \"" + $order + "\"");
    }
}

/**
 * Whether a tag is one the writer computes, never an entry.
 *
 * @param ifd {string} the IFD name
 * @param id {int} the tag number
 * @return {bool} true for the IFD pointers and the thumbnail location
 */
func isStructural(ifd as string, id as int) {
    if ($ifd == IFD0 and ($id == TAG_EXIF_POINTER or $id == TAG_GPS_POINTER)) {
        return true;
    }
    if ($ifd == IFD_EXIF and $id == TAG_INTEROP_POINTER) {
        return true;
    }
    return $ifd == IFD1 and ($id == TAG_THUMB_OFFSET or $id == TAG_THUMB_LENGTH);
}

/**
 * The smallest and largest value of an integer field type.
 *
 * @param type {int} 1, 3, 4, 6, 8 or 9
 * @return {list of int} `[min, max]`
 */
func intRange(type as int) {
    match ($type) {
        when 1 { return [0, 255]; }
        when 3 { return [0, 65535]; }
        when 4 { return [0, UINT32_MAX]; }
        when 6 { return [-128, 127]; }
        when 8 { return [-32768, 32767]; }
        else { return [-2147483648, 2147483647]; }
    }
}

/**
 * Check that integers fit a field type.
 *
 * @param values {list of int} the values
 * @param type {int} an integer field type
 * @param what {string} the tag, for the message
 * @throws {ExifError} naming the first value out of range
 */
func checkInts(values as list of int, type as int, what as string) {
    def r as list of int init intRange($type);
    for (def v in $values) {
        if ($v < $r[0] or $v > $r[1]) {
            fail($what + ": " + convert.toString($v) + " does not fit type " +
                convert.toString($type) +
                " (" + convert.toString($r[0]) + " to " + convert.toString($r[1]) + ")");
        }
    }
}

/**
 * The number of values a `Value` holds.
 *
 * @param value {Value} the value
 * @return {int} the element count (bytes for `Ascii` and `Undefined`)
 */
func valueCount(value as Value) {
    match ($value) {
        when Ints(p) { return len($p.values); }
        when Ascii(p) { return len($p.data); }
        when Undefined(p) { return len($p.data); }
        when Rationals(p) { return len($p.values); }
        when Floats(p) { return len($p.values); }
    }
}

/**
 * The name of an entry for messages: `ifd0:Make` or `gps:0x0020`.
 *
 * @param ifd {string} the IFD name
 * @param id {int} the tag number
 * @return {string} the label
 */
func label(ifd as string, id as int) {
    def name as string init "";
    if (lists.contains(IFDS, $ifd)) {
        $name = tagName($ifd, $id);
    }
    if ($name == "") {
        $name = hex4($id);
    }
    return $ifd + ":" + $name;
}

/**
 * Check an entry the writer is about to write.
 *
 * @param e {Entry} the entry
 * @throws {ExifError} for an unknown IFD or type, a structural tag, a value of the wrong variant, a count that disagrees with the value, or a value out of range
 */
func checkEntry(e as Entry) {
    checkIfd($e.ifd);
    def what as string init label($e.ifd, $e.tag);
    if ($e.tag < 0 or $e.tag > 65535) {
        fail("tag " + convert.toString($e.tag) + " is outside 0-65535");
    }
    if (isPointerTag($e.tag)) {
        fail($what + " is a pointer the writer computes and cannot be set");
    }
    if ($e.tag == TAG_STRIP_OFFSETS or $e.tag == TAG_TILE_OFFSETS) {
        fail($what + " points at image data the writer does not carry; use removeThumbnail");
    }
    if (typeSize($e.type) == 0) {
        fail($what + ": unknown field type " + convert.toString($e.type));
    }
    def ok as bool init false;
    match ($e.value) {
        when Ints(p) {
            $ok = lists.contains([1, 3, 4, 6, 8, 9], $e.type);
            if ($ok) {
                checkInts($p.values, $e.type, $what);
            }
        }
        when Ascii(p) { $ok = $e.type == TYPE_ASCII; }
        when Undefined(p) { $ok = $e.type == TYPE_UNDEFINED; }
        when Rationals(p) {
            $ok = $e.type == TYPE_RATIONAL or $e.type == TYPE_SRATIONAL;
            if ($ok) {
                def parts as list of int init [];
                for (def r in $p.values) {
                    $parts[] = $r.num;
                    $parts[] = $r.den;
                }
                def base as int init TYPE_LONG;
                if ($e.type == TYPE_SRATIONAL) {
                    $base = TYPE_SLONG;
                }
                checkInts($parts, $base, $what);
            }
        }
        when Floats(p) { $ok = $e.type == TYPE_FLOAT or $e.type == TYPE_DOUBLE; }
    }
    if (not $ok) {
        fail($what + ": the value does not match field type " + convert.toString($e.type));
    }
    if ($e.count != valueCount($e.value)) {
        fail($what + ": count " + convert.toString($e.count) + " but the value holds " +
            convert.toString(valueCount($e.value)));
    }
}

/**
 * Build an entry with an explicit field type, for a tag outside the table
 * or a type the setters do not pick.
 *
 * @param tag {string} the tag: a name (`"Make"`), `"ifd1:XResolution"`, or `"ifd:0x1234"` by number
 * @param type {int} the field type, `TYPE_BYTE` to `TYPE_DOUBLE`
 * @param value {Value} the value, of the variant the type needs
 * @return {Entry} the entry, `count` filled in
 * @throws {ExifError} for an unknown tag, a structural tag, or a value that does not fit the type
 * @example
 *   def e as exif.Entry init exif.makeEntry("exif:0xA460", exif.TYPE_SHORT, exif.Value.Ints{values: [1]});
 */
export func makeEntry(tag as string, type as int, value as Value) {
    def ref as TagRef init resolve($tag);
    def e as Entry init Entry{
        ifd: $ref.ifd,
        tag: $ref.id,
        type: $type,
        count: valueCount($value),
        value: $value
    };
    checkEntry($e);
    return $e;
}

/**
 * The index of a tag's entry, or -1.
 *
 * @param x {Exif} the metadata
 * @param ifd {string} the IFD name
 * @param id {int} the tag number
 * @return {int} the index in `entries`, -1 when absent
 */
func indexOf(x as Exif, ifd as string, id as int) {
    def i as int init 0;
    for (def e in $x.entries) {
        if ($e.tag == $id and $e.ifd == $ifd) {
            return $i;
        }
        $i = $i + 1;
    }
    return -1;
}

/**
 * Whether the metadata holds a tag.
 *
 * @param x {Exif} the metadata
 * @param tag {string} the tag, as for `get`
 * @return {bool} true when present
 * @throws {ExifError} for an unknown tag name
 */
export func has(x as Exif, tag as string) {
    def ref as TagRef init resolve($tag);
    return indexOf($x, $ref.ifd, $ref.id) >= 0;
}

/**
 * The entry of a tag.
 *
 * @param x {Exif} the metadata
 * @param tag {string} a name (`"Model"`), `"ifd1:XResolution"`, or `"gps:0x0002"` by number
 * @return {Entry} the entry
 * @throws {ExifError} when the tag is absent or unknown
 */
export func get(x as Exif, tag as string) {
    def ref as TagRef init resolve($tag);
    def i as int init indexOf($x, $ref.ifd, $ref.id);
    if ($i < 0) {
        fail("no " + label($ref.ifd, $ref.id) + " in this EXIF");
    }
    return $x.entries[$i];
}

/**
 * Add an entry, or replace the one with the same IFD and tag. A new entry
 * goes where `read` would put it: IFDs in the order IFD0, Exif, Interop,
 * GPS, IFD1, tags ascending within each.
 *
 * @param x {Exif} the metadata
 * @param entry {Entry} the entry, as `makeEntry` builds it
 * @return {Exif} the changed metadata
 * @throws {ExifError} when the entry does not check out (see `makeEntry`)
 */
export func set(x as Exif, entry as Entry) {
    checkEntry($entry);
    def i as int init indexOf($x, $entry.ifd, $entry.tag);
    if ($i >= 0) {
        $x.entries[$i] = $entry;
        return $x;
    }
    $x.entries = inserted($x.entries, $entry);
    return $x;
}

/**
 * The entries with one more, at its place in the canonical order.
 *
 * @param entries {list of Entry} the entries
 * @param entry {Entry} the new entry
 * @return {list of Entry} a new list
 */
func inserted(entries as list of Entry, entry as Entry) {
    def rank as int init lists.indexOf(IFDS, $entry.ifd);
    def out as list of Entry init [];
    def placed as bool init false;
    for (def e in $entries) {
        if (not $placed and isAfter($e, $rank, $entry.tag)) {
            $out[] = $entry;
            $placed = true;
        }
        $out[] = $e;
    }
    if (not $placed) {
        $out[] = $entry;
    }
    return $out;
}

/**
 * Whether an entry sorts after a position in the canonical order.
 *
 * @param e {Entry} the entry
 * @param rank {int} the other position's IFD index in `IFDS`
 * @param tag {int} the other position's tag
 * @return {bool} true when `e` comes later
 */
func isAfter(e as Entry, rank as int, tag as int) {
    def r as int init lists.indexOf(IFDS, $e.ifd);
    return $r > $rank or ($r == $rank and $e.tag > $tag);
}

/**
 * Remove a tag. Removing an absent tag changes nothing.
 *
 * @param x {Exif} the metadata
 * @param tag {string} the tag, as for `get`
 * @return {Exif} the changed metadata
 * @throws {ExifError} for an unknown tag name
 */
export func remove(x as Exif, tag as string) {
    def ref as TagRef init resolve($tag);
    def i as int init indexOf($x, $ref.ifd, $ref.id);
    if ($i >= 0) {
        def kept as list of Entry init [];
        for (def j in 0..len($x.entries)) {
            if ($j != $i) {
                $kept[] = $x.entries[$j];
            }
        }
        $x.entries = $kept;
    }
    return $x;
}

/**
 * Remove every entry of one IFD.
 *
 * @param x {Exif} the metadata
 * @param ifd {string} the IFD name
 * @return {Exif} the changed metadata
 */
func dropIfd(x as Exif, ifd as string) {
    def kept as list of Entry init [];
    for (def e in $x.entries) {
        if ($e.ifd != $ifd) {
            $kept[] = $e;
        }
    }
    $x.entries = $kept;
    return $x;
}

/**
 * Remove the GPS IFD: every location, altitude, direction and GPS time.
 *
 * @param x {Exif} the metadata
 * @return {Exif} the metadata without GPS entries
 */
export func removeGps(x as Exif) {
    return dropIfd($x, IFD_GPS);
}

/**
 * Remove the thumbnail: the JPEG and every IFD1 entry.
 *
 * @param x {Exif} the metadata
 * @return {Exif} the metadata without IFD1
 */
export func removeThumbnail(x as Exif) {
    def none as bytes;
    $x.thumbnail = $none;
    return dropIfd($x, IFD1);
}

/**
 * Set the JPEG thumbnail. IFD1 gets `Compression` 6 (JPEG) when it has no
 * `Compression` entry yet; the writer adds its offset and length.
 *
 * @param x {Exif} the metadata
 * @param jpeg {bytes} a JPEG image, starting `FF D8`
 * @return {Exif} the changed metadata
 * @throws {ExifError} when the bytes are not a JPEG
 */
export func setThumbnail(x as Exif, jpeg as bytes) {
    if (len($jpeg) < 4 or $jpeg[0] != 0xFF or $jpeg[1] != 0xD8) {
        fail("a thumbnail must be a JPEG image");
    }
    $x.thumbnail = $jpeg;
    if (indexOf($x, IFD1, 0x0103) < 0) {
        $x.entries = inserted(
            $x.entries,
            Entry{
                ifd: IFD1,
                tag: 0x0103,
                type: TYPE_SHORT,
                count: 1,
                value: Value.Ints{values: [6]}
            });
    }
    return $x;
}

/**
 * The table type of a tag, checked against what a setter writes.
 *
 * @param tag {string} the tag
 * @param allowed {list of int} the table types the setter accepts
 * @param setter {string} the setter's name, for the message
 * @return {TagRef} the resolved tag
 * @throws {ExifError} for a tag outside the table or of another type
 */
func refFor(tag as string, allowed as list of int, setter as string) {
    def ref as TagRef init resolve($tag);
    if ($ref.type < 0) {
        fail($setter + ": " + label($ref.ifd, $ref.id) +
            " is not in the tag table; build it with makeEntry");
    }
    if (not lists.contains($allowed, $ref.type)) {
        fail($setter + ": " + label($ref.ifd, $ref.id) + " has field type " +
            convert.toString($ref.type));
    }
    return $ref;
}

/**
 * Set a text tag (`ASCII`). The text is written as UTF-8 with a closing NUL.
 *
 * @param x {Exif} the metadata
 * @param tag {string} an `ASCII` tag of the table, such as `"Artist"`
 * @param text {string} the text, without NUL characters
 * @return {Exif} the changed metadata
 * @throws {ExifError} for a tag that is not text, or a NUL in the text
 * @example
 *   $e = exif.setText($e, "Copyright", "(C) 2026 Ada");
 */
export func setText(x as Exif, tag as string, text as string) {
    def ref as TagRef init refFor($tag, [TYPE_ASCII], "setText");
    if (strings.contains($text, "\0")) {
        fail("setText: the text holds a NUL character");
    }
    def data as bytes init encoding.encode("utf-8", $text);
    $data[] = 0;
    return set(
        $x,
        Entry{
            ifd: $ref.ifd,
            tag: $ref.id,
            type: TYPE_ASCII,
            count: len($data),
            value: Value.Ascii{data: $data}
        });
}

/**
 * Set an integer tag. `SHORT` or `LONG` tags (`ImageWidth`, ...) take
 * `SHORT` when every value fits it.
 *
 * @param x {Exif} the metadata
 * @param tag {string} an integer tag of the table, such as `"Orientation"`
 * @param values {list of int} the values
 * @return {Exif} the changed metadata
 * @throws {ExifError} for a tag that is not an integer, or a value out of its range
 */
export func setInts(x as Exif, tag as string, values as list of int) {
    def ref as TagRef init refFor($tag, [0, 1, 3, 4, 6, 8, 9], "setInts");
    def type as int init $ref.type;
    if ($type == TYPE_SHORT_OR_LONG) {
        $type = TYPE_SHORT;
        for (def v in $values) {
            if ($v > 65535) {
                $type = TYPE_LONG;
            }
        }
    }
    return set(
        $x,
        Entry{
            ifd: $ref.ifd,
            tag: $ref.id,
            type: $type,
            count: len($values),
            value: Value.Ints{values: $values}
        });
}

/**
 * Set a rational tag.
 *
 * @param x {Exif} the metadata
 * @param tag {string} a `RATIONAL` or `SRATIONAL` tag, such as `"ExposureTime"`
 * @param values {list of Rational} the values
 * @return {Exif} the changed metadata
 * @throws {ExifError} for a tag of another type, or a part out of range
 */
export func setRationals(x as Exif, tag as string, values as list of Rational) {
    def ref as TagRef init refFor($tag, [TYPE_RATIONAL, TYPE_SRATIONAL], "setRationals");
    return set(
        $x,
        Entry{
            ifd: $ref.ifd,
            tag: $ref.id,
            type: $ref.type,
            count: len($values),
            value: Value.Rationals{values: $values}
        });
}

/**
 * Set an `UNDEFINED` tag to raw bytes.
 *
 * @param x {Exif} the metadata
 * @param tag {string} an `UNDEFINED` tag, such as `"UserComment"`
 * @param data {bytes} the bytes
 * @return {Exif} the changed metadata
 * @throws {ExifError} for a tag of another type
 */
export func setRaw(x as Exif, tag as string, data as bytes) {
    def ref as TagRef init refFor($tag, [TYPE_UNDEFINED], "setRaw");
    return set(
        $x,
        Entry{
            ifd: $ref.ifd,
            tag: $ref.id,
            type: TYPE_UNDEFINED,
            count: len($data),
            value: Value.Undefined{data: $data}
        });
}

/**
 * A tag's text: the `ASCII` bytes up to the first NUL, as UTF-8.
 *
 * @param x {Exif} the metadata
 * @param tag {string} an `ASCII` tag
 * @return {string} the text
 * @throws {ExifError} when the tag is absent, not `ASCII`, or not valid UTF-8
 */
export func text(x as Exif, tag as string) {
    def e as Entry init get($x, $tag);
    match ($e.value) {
        when Ascii(p) { return asciiText($p.data, label($e.ifd, $e.tag)); }
        else {
            fail(label($e.ifd, $e.tag) + " is not text (type " + convert.toString($e.type) + ")");
        }
    }
}

/**
 * Decode `ASCII` bytes up to the first NUL.
 *
 * @param data {bytes} the stored bytes
 * @param what {string} the tag, for the message
 * @return {string} the text
 * @throws {ExifError} when the bytes are not UTF-8
 */
func asciiText(data as bytes, what as string) {
    def end as int init len($data);
    def nul as int init binary.indexOf($data, binary.make(1));
    if ($nul >= 0) {
        $end = $nul;
    }
    try {
        return encoding.decode("utf-8", $data[0..$end]);
    } catch (e) {
        fail($what + " is not valid UTF-8 text");
    }
}

/**
 * A tag's integers.
 *
 * @param x {Exif} the metadata
 * @param tag {string} an integer tag
 * @return {list of int} the values
 * @throws {ExifError} when the tag is absent or not an integer type
 */
export func ints(x as Exif, tag as string) {
    def e as Entry init get($x, $tag);
    match ($e.value) {
        when Ints(p) { return $p.values; }
        else {
            fail(label($e.ifd, $e.tag) + " is not an integer (type " + convert.toString($e.type) +
                ")");
        }
    }
}

/**
 * A tag's rationals.
 *
 * @param x {Exif} the metadata
 * @param tag {string} a `RATIONAL` or `SRATIONAL` tag
 * @return {list of Rational} the values
 * @throws {ExifError} when the tag is absent or of another type
 */
export func rationals(x as Exif, tag as string) {
    def e as Entry init get($x, $tag);
    match ($e.value) {
        when Rationals(p) { return $p.values; }
        else {
            fail(label($e.ifd, $e.tag) + " is not rational (type " + convert.toString($e.type) + ")");
        }
    }
}

/**
 * A rational as a float.
 *
 * @param r {Rational} the fraction
 * @param what {string} the tag, for the message
 * @return {float} `num / den`
 * @throws {ExifError} when the denominator is 0
 */
func ratio(r as Rational, what as string) {
    if ($r.den == 0) {
        fail($what + " has a zero denominator");
    }
    return $r.num / $r.den;
}

/**
 * Any numeric tag as floats: integers, rationals (`num / den`) or floats.
 *
 * @param x {Exif} the metadata
 * @param tag {string} a numeric tag, such as `"FNumber"`
 * @return {list of float} the values
 * @throws {ExifError} when the tag is absent, not numeric, or a rational has a zero denominator
 */
export func floats(x as Exif, tag as string) {
    def e as Entry init get($x, $tag);
    def what as string init label($e.ifd, $e.tag);
    def out as list of float init [];
    match ($e.value) {
        when Ints(p) {
            for (def v in $p.values) {
                $out[] = convert.toFloat($v);
            }
        }
        when Rationals(p) {
            for (def r in $p.values) {
                $out[] = ratio($r, $what);
            }
        }
        when Floats(p) { $out = $p.values; }
        else { fail($what + " is not numeric (type " + convert.toString($e.type) + ")"); }
    }
    return $out;
}

/**
 * A tag's stored bytes: `UNDEFINED` and `ASCII` as stored, `BYTE` and
 * `SBYTE` as bytes.
 *
 * @param x {Exif} the metadata
 * @param tag {string} a byte-sized tag
 * @return {bytes} the bytes
 * @throws {ExifError} when the tag is absent or wider than a byte
 */
export func raw(x as Exif, tag as string) {
    def e as Entry init get($x, $tag);
    match ($e.value) {
        when Ascii(p) { return $p.data; }
        when Undefined(p) { return $p.data; }
        when Ints(p) {
            if ($e.type == TYPE_BYTE or $e.type == TYPE_SBYTE) {
                def out as bytes;
                for (def v in $p.values) {
                    $out[] = $v & 0xff;
                }
                return $out;
            }
        }
        else {
        }
    }
    fail(label($e.ifd, $e.tag) + " is not byte data (type " + convert.toString($e.type) + ")");
}
