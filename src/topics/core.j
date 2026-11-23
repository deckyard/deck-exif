# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.27.0

# exif - errors, caps and the byte-level helpers every other topic uses.
# Spliced into exif.j via include - not a standalone module.

/** The default cap on the size of one EXIF payload: 16 MiB. */
export def const MAX_BYTES as int init 16777216;

/** The default cap on the entries of one IFD. */
export def const MAX_ENTRIES as int init 1000;

/** The default cap on the bytes of one value (`count` times the type's size): 1 MiB. */
export def const MAX_VALUE_BYTES as int init 1048576;

/**
 * The cap on the numbers (integers, rational parts, floats) one payload
 * decodes to. Each costs far more memory than its bytes, and every value
 * may point at the same bytes, so this bounds memory where the byte caps
 * do not. Text and raw bytes do not count. Fixed: `Options` does not change it.
 */
export def const MAX_NUMBERS as int init 65536;

/** The largest unsigned 32-bit value. */
def const UINT32_MAX as int init 4294967295;

/**
 * A failure of this deck. Every error of kind `"exif"` is one, so `offset`
 * is safe to read once the kind matches. A reached cap is a plain `Error`
 * of kind `"limit"` instead.
 *
 * @field kind {string} always `"exif"`
 * @field message {string} `exif: ` and what went wrong
 * @field offset {int} the byte offset in the input where the problem is, `-1` when there is none (a bad argument)
 */
export def struct ExifError {
    kind as string,
    message as string,
    offset as int
};

/**
 * Caps for `readWith` and `parseWith`. A zero field keeps the default; the
 * caps can only be lowered.
 *
 * @field maxBytes {int} the largest EXIF payload, default `MAX_BYTES`
 * @field maxEntries {int} the most entries in one IFD, default `MAX_ENTRIES`
 * @field maxValueBytes {int} the largest value, default `MAX_VALUE_BYTES`
 */
export def struct Options {
    maxBytes as int,
    maxEntries as int,
    maxValueBytes as int
};

/**
 * Throw an `ExifError` without an offset: a bad argument.
 *
 * @param message {string} what went wrong, without the `exif: ` prefix
 * @throws {ExifError} kind "exif", always
 */
func fail(message as string) {
    failAt($message, -1);
}

/**
 * Throw an `ExifError` for malformed data at a byte offset.
 *
 * @param message {string} what went wrong, without the `exif: ` prefix
 * @param offset {int} where in the input
 * @throws {ExifError} kind "exif", always
 */
func failAt(message as string, offset as int) {
    throw ExifError{kind: "exif", message: "exif: " + $message, offset: $offset};
}

/**
 * Throw a reached cap.
 *
 * @param message {string} what went past which cap, without the `exif: ` prefix
 * @throws {Error} kind "limit", always
 */
func failLimit(message as string) {
    throw Error{kind: "limit", message: "exif: " + $message};
}

/**
 * One cap of `Options`, its default filled in and checked.
 *
 * @param value {int} the caller's value, 0 for the default
 * @param fallback {int} the default, also the largest value allowed
 * @param name {string} the field, for the message
 * @return {int} the cap in force
 * @throws {ExifError} when the value is negative or above the default
 */
func capOf(value as int, fallback as int, name as string) {
    if ($value == 0) {
        return $fallback;
    }
    if ($value < 0 or $value > $fallback) {
        fail("Options." + $name + " must be 1 to " + convert.toString($fallback) + ", got " +
            convert.toString($value));
    }
    return $value;
}

/**
 * The caps in force: every zero field replaced by its default.
 *
 * @param options {Options} the caller's options
 * @return {Options} the caps, all positive
 * @throws {ExifError} when a field is negative or above its default
 */
func capsOf(options as Options) {
    return Options{
        maxBytes: capOf($options.maxBytes, MAX_BYTES, "maxBytes"),
        maxEntries: capOf($options.maxEntries, MAX_ENTRIES, "maxEntries"),
        maxValueBytes: capOf($options.maxValueBytes, MAX_VALUE_BYTES, "maxValueBytes")
    };
}

/**
 * Check that `count` bytes at `offset` lie before `end`.
 *
 * @param offset {int} where the read starts
 * @param count {int} how many bytes it needs
 * @param end {int} the first byte past the region
 * @param what {string} what is being read, for the message
 * @throws {ExifError} naming the offset when the bytes are not all there
 */
func need(offset as int, count as int, end as int, what as string) {
    if ($offset < 0 or $offset + $count > $end) {
        failAt(
            "truncated " + $what + ": " + convert.toString($count) + " bytes at " +
                convert.toString($offset) + " run past " + convert.toString($end),
            $offset);
    }
}

/**
 * The bytes of an unsigned (or two's complement) integer.
 *
 * The one place integers are written; switch it to a `binary` writer once
 * the library has one (roadmap M29.54).
 *
 * @param order {string} `"le"` or `"be"`
 * @param value {int} the value; only its low `size` bytes are written
 * @param size {int} 1 to 8
 * @return {bytes} `size` bytes
 */
func uintBytes(order as string, value as int, size as int) {
    def out as bytes init binary.make($size);
    for (def i in 0..$size) {
        def octet as int init ($value >> (8 * $i)) & 0xff;
        if ($order == "le") {
            $out[$i] = $octet;
        } else {
            $out[$size - 1 - $i] = $octet;
        }
    }
    return $out;
}

/**
 * Round half to even.
 *
 * @param x {float} a non-negative value
 * @return {int} the nearest integer, ties to the even one
 */
func roundEven(x as float) {
    def low as int init math.floor($x);
    def rest as float init $x - $low;
    if ($rest > 0.5 or ($rest == 0.5 and $low % 2 == 1)) {
        return $low + 1;
    }
    return $low;
}

/**
 * The IEEE 754 bit pattern of a float, single or double precision.
 *
 * `binary` reads floats but cannot write them yet, so this encodes by hand:
 * the exponent from `log2`, corrected by one either way, then the mantissa
 * rounded half to even. Subnormals are kept; `-0.0` is written as `0.0`.
 *
 * @param x {float} the value
 * @param size {int} 4 (single) or 8 (double)
 * @return {int} the bits; for size 8 the sign is bit 63, so negative values give a negative int
 * @throws {ExifError} when the value is too large for a single-precision float
 */
func floatBits(x as float, size as int) {
    def expBits as int init 11;
    def mantBits as int init 52;
    if ($size == 4) {
        $expBits = 8;
        $mantBits = 23;
    }
    def bias as int init (1 << ($expBits - 1)) - 1;
    def sign as int init 0;
    def a as float init $x;
    if ($x < 0.0) {
        $sign = 1;
        $a = -$x;
    }
    def signBit as int init $sign << ($expBits + $mantBits);
    if ($a == 0.0) {
        return $signBit;
    }
    # log2 may round across a power of two; clamp it to where pow stays finite
    # and non-zero, then let the loops below settle the exponent
    def e as int init math.max(-1074, math.min(1023, math.floor(math.log2($a))));
    def scaled as float init $a / math.pow(2.0, $e);
    while ($scaled >= 2.0) {
        $e = $e + 1;
        $scaled = $scaled / 2.0;
    }
    while ($scaled < 1.0) {
        $e = $e - 1;
        $scaled = $scaled * 2.0;
    }
    def full as int init 1 << $mantBits;
    if ($e < 1 - $bias) {
        def tiny as int init roundEven($a / math.pow(2.0, 1 - $bias - $mantBits));
        if ($tiny == $full) {
            return $signBit | $full;
        }
        return $signBit | $tiny;
    }
    def mant as int init roundEven(($scaled - 1.0) * math.pow(2.0, $mantBits));
    if ($mant == $full) {
        $mant = 0;
        $e = $e + 1;
    }
    if ($e > $bias) {
        fail(convert.toString($x) + " is too large for a " + convert.toString($size * 8) +
            "-bit float");
    }
    return $signBit | (($e + $bias) << $mantBits) | $mant;
}

/**
 * The bytes of an ASCII text.
 *
 * @param s {string} plain ASCII
 * @return {bytes} its bytes
 */
func ascii(s as string) {
    return encoding.encode("utf-8", $s);
}

/**
 * Whether `data` holds `want` at `offset`, without copying.
 *
 * @param data {bytes} the buffer
 * @param offset {int} where to look
 * @param want {bytes} the expected bytes
 * @return {bool} true when every byte matches; false when they run past the end
 */
func hasAt(data as bytes, offset as int, want as bytes) {
    def end as int init $offset + len($want);
    if ($offset < 0 or $end > len($data)) {
        return false;
    }
    return binary.indexOf($data, $want, $offset, $end) == $offset;
}

/**
 * A number in hexadecimal, `0x` and four digits at least.
 *
 * @param n {int} a non-negative value
 * @return {string} such as `0x010F`
 */
func hex4(n as int) {
    return "0x" + strings.upper(io.sprintf("%d|base=16|pad=4|fill=0", $n));
}
