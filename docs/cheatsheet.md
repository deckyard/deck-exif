<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# Cheatsheet

Every export of `@deckyard/exif`, by topic, called through the import alias:
`import "@deckyard/exif/" as exif;` then `exif.read(data)`.
`tools/check-docs.sh` checks each signature against the source.

A `tag` argument is a string: a name from the [tag table](tags.md)
(`"Make"`), a name with its IFD (`"ifd1:XResolution"`), or an IFD and a
number (`"gps:0x0002"`, `"exif:42036"`).

## Images

| Signature | Returns | Does |
|---|---|---|
| `format(data)` | `string` | `"jpeg"`, `"png"` or `"webp"`, from the first bytes; anything else throws. |
| `hasExif(data)` | `bool` | Whether the image has an EXIF segment or chunk. |
| `read(data)` | `Exif` | The image's EXIF; an empty `Exif` (`"be"`) when it has none. |
| `readWith(data, options)` | `Exif` | `read` with lowered caps. |
| `write(data, x)` | `bytes` | The image with `x` as its EXIF; only the EXIF segment or chunk changes. |
| `strip(data)` | `bytes` | The image without EXIF; unchanged when it has none. |

## Files

| Signature | Returns | Does |
|---|---|---|
| `readFile(path)` | `Exif` | `read` of a file. |
| `writeFile(path, x)` | `null` | `write` into a file, replaced atomically (temporary file and rename). |
| `stripFile(path)` | `null` | `strip` a file, replaced atomically. |

## Payloads

| Signature | Returns | Does |
|---|---|---|
| `parse(payload)` | `Exif` | Read a bare TIFF-structured payload (`II*\0...` / `MM\0*...`). |
| `parseWith(payload, options)` | `Exif` | `parse` with lowered caps. |
| `render(x)` | `bytes` | Serialise to a payload: offsets computed, tags sorted, values word-aligned. |

## The model

### `Exif`

| Field | Holds |
|---|---|
| `order as string` | `"le"` (`II`) or `"be"` (`MM`); `write` keeps it |
| `entries as list of Entry` | every tag of every IFD, without the IFD pointers and thumbnail location |
| `thumbnail as bytes` | the IFD1 JPEG, empty when there is none |

### `Entry`

| Field | Holds |
|---|---|
| `ifd as string` | `IFD0`, `IFD_EXIF`, `IFD_GPS`, `IFD_INTEROP` or `IFD1` |
| `tag as int` | the tag number |
| `type as int` | the field type, `TYPE_BYTE` to `TYPE_DOUBLE` |
| `count as int` | the number of values (bytes for `ASCII` and `UNDEFINED`) |
| `value as Value` | the value |

### `Value`

| Variant | Payload | Holds |
|---|---|---|
| `Ints` | `values` (`list of int`) | `BYTE`, `SHORT`, `LONG`, `SBYTE`, `SSHORT`, `SLONG` |
| `Ascii` | `data` (`bytes`) | `ASCII`, as stored, NUL included |
| `Undefined` | `data` (`bytes`) | `UNDEFINED` |
| `Rationals` | `values` (`list of Rational`) | `RATIONAL`, `SRATIONAL` |
| `Floats` | `values` (`list of float`) | `FLOAT`, `DOUBLE` |

### `Rational`

| Field | Holds |
|---|---|
| `num as int` | the numerator |
| `den as int` | the denominator; 0 is kept as read |

| Signature | Returns | Does |
|---|---|---|
| `empty(order)` | `Exif` | No entries, no thumbnail. |
| `makeEntry(tag, type, value)` | `Entry` | An entry with an explicit type, `count` filled in, checked. |
| `tagName(ifd, tag)` | `string` | The standard name of a tag number in an IFD, `""` when unknown. |
| `describe(e)` | `string` | The value for people: text, `1, 2`, `1/125`, hex for short binary data. |

## Entries

| Signature | Returns | Does |
|---|---|---|
| `has(x, tag)` | `bool` | Whether the tag is present. |
| `get(x, tag)` | `Entry` | The entry; throws when absent. |
| `set(x, entry)` | `Exif` | Add or replace an entry, kept in IFD and tag order. |
| `remove(x, tag)` | `Exif` | Remove a tag; an absent one changes nothing. |
| `setText(x, tag, text)` | `Exif` | An `ASCII` tag, as UTF-8 with a closing NUL. |
| `setInts(x, tag, values)` | `Exif` | An integer tag; `SHORT` or `LONG` tags take `SHORT` when the values fit. |
| `setRationals(x, tag, values)` | `Exif` | A `RATIONAL` or `SRATIONAL` tag. |
| `setRaw(x, tag, data)` | `Exif` | An `UNDEFINED` tag. |
| `text(x, tag)` | `string` | An `ASCII` value up to its first NUL, as UTF-8; other bytes throw. |
| `ints(x, tag)` | `list of int` | An integer value. |
| `rationals(x, tag)` | `list of Rational` | A rational value. |
| `floats(x, tag)` | `list of float` | Any numeric value as floats; a zero denominator throws. |
| `raw(x, tag)` | `bytes` | An `UNDEFINED`, `ASCII`, `BYTE` or `SBYTE` value as bytes. |

## Privacy and the thumbnail

| Signature | Returns | Does |
|---|---|---|
| `removeGps(x)` | `Exif` | Remove the GPS IFD. |
| `removeThumbnail(x)` | `Exif` | Remove IFD1 and its JPEG. |
| `setThumbnail(x, jpeg)` | `Exif` | Set the JPEG thumbnail; adds IFD1 `Compression` 6 when missing. |

## Readers

### `Gps`

| Field | Holds |
|---|---|
| `latitude as float` | decimal degrees, north positive |
| `longitude as float` | decimal degrees, east positive |
| `altitude as float` | metres, negative below sea level; 0 without one |
| `hasAltitude as bool` | whether an altitude is recorded |

| Signature | Returns | Does |
|---|---|---|
| `orientation(x)` | `int` | `Orientation`, 1 to 8. |
| `hasGps(x)` | `bool` | Whether latitude and longitude with their references are present. |
| `gps(x)` | `Gps` | The position in decimal degrees. |
| `setGps(x, latitude, longitude)` | `Exif` | Write latitude and longitude (and `GPSVersionID` when missing). |
| `gpsTime(x)` | `time.Time` | `GPSDateStamp` and `GPSTimeStamp`, in UTC. |
| `dateTime(x, tag, zone)` | `time.Time` | `DateTimeOriginal`, `DateTimeDigitized` or `DateTime`, in its `OffsetTime*` zone, else `zone`; with `SubSecTime*`. |

## Constants

| Constant | Value | Meaning |
|---|---|---|
| `IFD0` | `"ifd0"` | The main image's IFD. |
| `IFD_EXIF` | `"exif"` | The Exif IFD. |
| `IFD_GPS` | `"gps"` | The GPS IFD. |
| `IFD_INTEROP` | `"interop"` | The Interoperability IFD. |
| `IFD1` | `"ifd1"` | The thumbnail's IFD. |
| `TYPE_BYTE` | `1` | Unsigned 8-bit. |
| `TYPE_ASCII` | `2` | NUL-terminated text. |
| `TYPE_SHORT` | `3` | Unsigned 16-bit. |
| `TYPE_LONG` | `4` | Unsigned 32-bit. |
| `TYPE_RATIONAL` | `5` | Two unsigned 32-bit. |
| `TYPE_SBYTE` | `6` | Signed 8-bit. |
| `TYPE_UNDEFINED` | `7` | Bytes. |
| `TYPE_SSHORT` | `8` | Signed 16-bit. |
| `TYPE_SLONG` | `9` | Signed 32-bit. |
| `TYPE_SRATIONAL` | `10` | Two signed 32-bit. |
| `TYPE_FLOAT` | `11` | IEEE 754 single. |
| `TYPE_DOUBLE` | `12` | IEEE 754 double. |
| `MAX_BYTES` | `16777216` | Default cap on one EXIF payload. |
| `MAX_ENTRIES` | `1000` | Default cap on the entries of one IFD. |
| `MAX_VALUE_BYTES` | `1048576` | Default cap on one value (and the thumbnail). |

## Errors and options

### `ExifError`

| Field | Holds |
|---|---|
| `kind as string` | always `"exif"` |
| `message as string` | `exif: ` and what went wrong |
| `offset as int` | the byte offset in the input, `-1` when none |

### `Options`

| Field | Holds |
|---|---|
| `maxBytes as int` | payload cap, 0 for `MAX_BYTES` |
| `maxEntries as int` | entries per IFD, 0 for `MAX_ENTRIES` |
| `maxValueBytes as int` | bytes per value, 0 for `MAX_VALUE_BYTES` |

A reached cap throws an `Error` of kind `"limit"`; `fs` errors of the file
helpers pass through unchanged.
