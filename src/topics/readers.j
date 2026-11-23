# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.27.0

# exif - readers for the common questions: orientation, location, dates,
# and a printable form of any entry.
# Spliced into exif.j via include - not a standalone module.

/**
 * A GPS position.
 *
 * @field latitude {float} decimal degrees, north positive
 * @field longitude {float} decimal degrees, east positive
 * @field altitude {float} metres above sea level, negative below; 0 when `hasAltitude` is false
 * @field hasAltitude {bool} whether the image records an altitude
 */
export def struct Gps {
    latitude as float,
    longitude as float,
    altitude as float,
    hasAltitude as bool
};

/**
 * The orientation: 1 is upright, 3 rotated 180 degrees, 6 needs a turn
 * clockwise, 8 counter-clockwise; 2, 4, 5 and 7 are mirrored.
 *
 * @param x {Exif} the metadata
 * @return {int} 1 to 8
 * @throws {ExifError} when the image has no `Orientation` or it is out of range
 */
export func orientation(x as Exif) {
    def vs as list of int init ints($x, "Orientation");
    if (len($vs) != 1 or $vs[0] < 1 or $vs[0] > 8) {
        fail("Orientation must be one value 1 to 8");
    }
    return $vs[0];
}

/**
 * Whether the metadata holds a GPS position (latitude and longitude with
 * their references).
 *
 * @param x {Exif} the metadata
 * @return {bool} true when all four tags are present
 */
export func hasGps(x as Exif) {
    return has($x, "GPSLatitude") and has($x, "GPSLatitudeRef") and has($x, "GPSLongitude") and
        has($x, "GPSLongitudeRef");
}

/**
 * Degrees, minutes and seconds as decimal degrees, signed by the reference.
 *
 * @param x {Exif} the metadata
 * @param tag {string} `"GPSLatitude"` or `"GPSLongitude"`
 * @param positive {string} the reference for a positive value, `"N"` or `"E"`
 * @param negative {string} the reference for a negative value, `"S"` or `"W"`
 * @return {float} the degrees
 * @throws {ExifError} for a value that is not three rationals, a zero denominator, or an unknown reference
 */
func degrees(x as Exif, tag as string, positive as string, negative as string) {
    def rs as list of Rational init rationals($x, $tag);
    if (len($rs) != 3) {
        fail($tag + " must be three rationals (degrees, minutes, seconds)");
    }
    def v as float init ratio($rs[0], $tag) + ratio($rs[1], $tag) / 60.0 +
        ratio($rs[2], $tag) / 3600.0;
    def ref as string init text($x, $tag + "Ref");
    if ($ref == $negative) {
        return -$v;
    }
    if ($ref != $positive) {
        fail($tag + "Ref must be " + $positive + " or " + $negative + ", got \"" + $ref + "\"");
    }
    return $v;
}

/**
 * The GPS position in decimal degrees, with the altitude when recorded.
 *
 * @param x {Exif} the metadata
 * @return {Gps} the position
 * @throws {ExifError} when the position is missing or malformed
 * @example
 *   if (exif.hasGps($e)) {
 *       def g as exif.Gps init exif.gps($e);
 *       io.printf("%f, %f\n", $g.latitude, $g.longitude);
 *   }
 */
export func gps(x as Exif) {
    def out as Gps init Gps{
        latitude: degrees($x, "GPSLatitude", "N", "S"),
        longitude: degrees($x, "GPSLongitude", "E", "W"),
        altitude: 0.0,
        hasAltitude: false
    };
    if (has($x, "GPSAltitude")) {
        def rs as list of Rational init rationals($x, "GPSAltitude");
        if (len($rs) != 1) {
            fail("GPSAltitude must be one rational");
        }
        $out.altitude = ratio($rs[0], "GPSAltitude");
        $out.hasAltitude = true;
        if (has($x, "GPSAltitudeRef")) {
            def ref as list of int init ints($x, "GPSAltitudeRef");
            if (len($ref) != 1 or $ref[0] > 1) {
                fail("GPSAltitudeRef must be 0 (above sea level) or 1 (below)");
            }
            if ($ref[0] == 1) {
                $out.altitude = -$out.altitude;
            }
        }
    }
    return $out;
}

/**
 * Decimal degrees as degrees, minutes and seconds, to a millionth of a
 * second.
 *
 * @param value {float} the absolute value in degrees
 * @return {list of Rational} degrees / 1, minutes / 1, seconds / 1000000
 */
func dms(value as float) {
    def micro as int init math.round($value * 3600000000.0);
    def deg as int init $micro // 3600000000;
    def rest as int init $micro % 3600000000;
    return [
        Rational{num: $deg, den: 1},
        Rational{num: $rest // 60000000, den: 1},
        Rational{num: $rest % 60000000, den: 1000000}
    ];
}

/**
 * Set the GPS position. Writes `GPSLatitude`, `GPSLongitude` and their
 * references, and `GPSVersionID` 2.3.0.0 when there is none; altitude and
 * time are left as they are.
 *
 * @param x {Exif} the metadata
 * @param latitude {float} decimal degrees, -90 to 90
 * @param longitude {float} decimal degrees, -180 to 180
 * @return {Exif} the changed metadata
 * @throws {ExifError} for a coordinate out of range
 */
export func setGps(x as Exif, latitude as float, longitude as float) {
    if ($latitude < -90.0 or $latitude > 90.0) {
        fail("setGps: latitude must be -90 to 90, got " + convert.toString($latitude));
    }
    if ($longitude < -180.0 or $longitude > 180.0) {
        fail("setGps: longitude must be -180 to 180, got " + convert.toString($longitude));
    }
    if (not has($x, "GPSVersionID")) {
        $x = setInts($x, "GPSVersionID", [2, 3, 0, 0]);
    }
    def latRef as string init "N";
    if ($latitude < 0.0) {
        $latRef = "S";
    }
    def lonRef as string init "E";
    if ($longitude < 0.0) {
        $lonRef = "W";
    }
    $x = setText($x, "GPSLatitudeRef", $latRef);
    $x = setRationals($x, "GPSLatitude", dms(math.abs($latitude)));
    $x = setText($x, "GPSLongitudeRef", $lonRef);
    $x = setRationals($x, "GPSLongitude", dms(math.abs($longitude)));
    return $x;
}

/**
 * The parts of an EXIF date and time text `YYYY:MM:DD HH:MM:SS`.
 *
 * @param s {string} the text
 * @param what {string} the tag, for the message
 * @return {list of string} year, month, day, hour, minute, second
 * @throws {ExifError} when the text has another shape (blank, spaces for unknown parts, ...)
 */
func dateParts(s as string, what as string) {
    def m as regex.Match init regex.find('^(\d{4}):(\d{2}):(\d{2}) (\d{2}):(\d{2}):(\d{2})$', $s);
    if ($m.start < 0) {
        fail($what + " is not a date and time \"YYYY:MM:DD HH:MM:SS\": \"" + $s + "\"");
    }
    return $m.groups;
}

/**
 * A time from ISO text, with a deck error when the values are not a date.
 *
 * @param iso {string} RFC 3339 text
 * @param what {string} the tag, for the message
 * @return {time.Time} the time
 * @throws {ExifError} for an impossible date or time
 */
func isoTime(iso as string, what as string) {
    try {
        return time.fromIso($iso);
    } catch (e) {
        fail($what + " is not a valid date and time: " + $iso);
    }
}

/**
 * A zone offset as `+HH:MM`.
 *
 * @param seconds {int} seconds east of UTC
 * @return {string} the offset
 */
func offsetText(seconds as int) {
    def sign as string init "+";
    def s as int init $seconds;
    if ($s < 0) {
        $sign = "-";
        $s = -$s;
    }
    return $sign + io.sprintf("%d|pad=2|fill=0", $s // 3600) + ":" +
        io.sprintf("%d|pad=2|fill=0", ($s % 3600) // 60);
}

/**
 * A date and time tag as a time. The zone is the matching `OffsetTime*`
 * tag when the image has one, else `zone`: EXIF times are the camera's
 * local time, and only the caller knows which zone that was. The matching
 * `SubSecTime*` tag adds the fraction of a second; a blank one (spaces
 * only, the standard's "unknown") adds nothing.
 *
 * @param x {Exif} the metadata
 * @param tag {string} `"DateTimeOriginal"`, `"DateTimeDigitized"` or `"DateTime"`
 * @param zone {time.Zone} the zone to assume when the image records none, such as `time.UTC`
 * @return {time.Time} the time
 * @throws {ExifError} for another tag, a missing tag, or text that is not a date and time
 * @example
 *   def taken as time.Time init exif.dateTime($e, "DateTimeOriginal", time.UTC);
 */
export func dateTime(x as Exif, tag as string, zone as time.Zone) {
    def offsetTag as string init "";
    def subTag as string init "";
    match ($tag) {
        when "DateTimeOriginal" {
            $offsetTag = "OffsetTimeOriginal";
            $subTag = "SubSecTimeOriginal";
        }
        when "DateTimeDigitized" {
            $offsetTag = "OffsetTimeDigitized";
            $subTag = "SubSecTimeDigitized";
        }
        when "DateTime" {
            $offsetTag = "OffsetTime";
            $subTag = "SubSecTime";
        }
        else {
            fail("dateTime: " + $tag + " is not DateTimeOriginal, DateTimeDigitized or DateTime");
        }
    }
    def p as list of string init dateParts(text($x, $tag), $tag);
    def offset as string init offsetText($zone.offset);
    if (has($x, $offsetTag)) {
        $offset = text($x, $offsetTag);
        if (not regex.matches('^[+-]\d{2}:\d{2}$', $offset)) {
            fail($offsetTag + " is not \"+HH:MM\": \"" + $offset + "\"");
        }
    }
    def fraction as string init "";
    if (has($x, $subTag)) {
        def sub as string init strings.trimRightSet(text($x, $subTag), " ");
        if ($sub != "") {
            if (not regex.matches('^\d{1,9}$', $sub)) {
                fail($subTag + " is not digits: \"" + $sub + "\"");
            }
            $fraction = "." + $sub;
        }
    }
    return isoTime(
        $p[0] + "-" + $p[1] + "-" + $p[2] + "T" + $p[3] + ":" + $p[4] + ":" + $p[5] + $fraction +
            $offset,
        $tag);
}

/**
 * The GPS time (UTC by definition) from `GPSDateStamp` and `GPSTimeStamp`.
 *
 * @param x {Exif} the metadata
 * @return {time.Time} the time, in UTC
 * @throws {ExifError} when either tag is missing or malformed
 */
export func gpsTime(x as Exif) {
    def m as regex.Match init regex.find('^(\d{4}):(\d{2}):(\d{2})$', text($x, "GPSDateStamp"));
    if ($m.start < 0) {
        fail("GPSDateStamp is not \"YYYY:MM:DD\"");
    }
    def rs as list of Rational init rationals($x, "GPSTimeStamp");
    if (len($rs) != 3) {
        fail("GPSTimeStamp must be three rationals (hour, minute, second)");
    }
    def parts as list of int init [];
    for (def r in $rs[0..2]) {
        if ($r.den == 0 or $r.num % $r.den != 0) {
            fail("GPSTimeStamp: hours and minutes must be whole numbers");
        }
        $parts[] = $r.num // $r.den;
    }
    def sec as Rational init $rs[2];
    if ($sec.den == 0) {
        fail("GPSTimeStamp has a zero denominator");
    }
    def nanos as int init (($sec.num % $sec.den) * 1000000000) // $sec.den;
    def iso as string init $m.groups[0] + "-" + $m.groups[1] + "-" + $m.groups[2] + "T" +
        io.sprintf("%d|pad=2|fill=0", $parts[0]) + ":" + io.sprintf("%d|pad=2|fill=0", $parts[1]) +
        ":" +
        io.sprintf("%d|pad=2|fill=0", $sec.num // $sec.den) + "." +
        io.sprintf("%d|pad=9|fill=0", $nanos) + "Z";
    return isoTime($iso, "GPSTimeStamp");
}

/**
 * An entry's value as text for people: text as text, numbers separated by
 * `, `, rationals as `num/den`, up to 16 bytes of binary data in hex and
 * the length of longer data.
 *
 * @param e {Entry} the entry
 * @return {string} the value
 */
export func describe(e as Entry) {
    def parts as list of string init [];
    match ($e.value) {
        when Ints(p) {
            for (def v in $p.values) {
                $parts[] = convert.toString($v);
            }
        }
        when Rationals(p) {
            for (def r in $p.values) {
                $parts[] = convert.toString($r.num) + "/" + convert.toString($r.den);
            }
        }
        when Floats(p) {
            for (def f in $p.values) {
                $parts[] = convert.toString($f);
            }
        }
        when Ascii(p) {
            try {
                return asciiText($p.data, "");
            } catch (err) {
                return hexOf($p.data);
            }
        }
        when Undefined(p) { return hexOf($p.data); }
    }
    return strings.join($parts, ", ");
}

/**
 * Bytes as hex for `describe`: up to 16 bytes, else their count.
 *
 * @param data {bytes} the bytes
 * @return {string} such as `30 32 33 32` or `(4096 bytes)`
 */
func hexOf(data as bytes) {
    if (len($data) > 16) {
        return "(" + convert.toString(len($data)) + " bytes)";
    }
    def parts as list of string init [];
    for (def b in $data) {
        $parts[] = io.sprintf("%d|base=16|pad=2|fill=0", $b);
    }
    return strings.join($parts, " ");
}
