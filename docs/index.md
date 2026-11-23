<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# @deckyard/exif

Read, change and remove the EXIF metadata of JPEG, PNG and WebP images, in
pure Jennifer on `bytes`. The deck reads the whole EXIF structure (IFD0, the
Exif, GPS and Interoperability IFDs, IFD1 and its thumbnail, all twelve
field types), lets you set and remove single tags, and writes the image back
with only its EXIF segment or chunk replaced: pixel data and every other
byte stay as they were.

- [Reading, changing and removing](guide.md): the calls, by task
- [Tag table](tags.md): the tags known by name and their types
- [Cheatsheet](cheatsheet.md): every export
- [Design](design.md): scope, decisions, limits

## Conventions

Snippets assume this import:

```jennifer
import "@deckyard/exif/" as exif;

def e as exif.Exif init exif.read(fs.readBytes("photo.jpg"));
io.printf("%s\n", exif.text($e, "Model"));
```

Functions that change an `Exif` return the changed copy:
`$e = exif.setText($e, "Artist", "Ada");`.

## Errors

| Kind | Thrown as | When |
|---|---|---|
| `"exif"` | `exif.ExifError{kind, message, offset}` | malformed image or EXIF data (`offset` is where, in the bytes you passed), or misuse: an unknown tag name, a value that does not fit its type, an absent tag read with `get` / `text` / ... |
| `"limit"` | `Error` | a cap was reached: 16 MiB of EXIF, 1,000 entries in one IFD, 1 MiB in one value (lower them with `readWith` / `parseWith`) |

`fs` errors from `readFile`, `writeFile` and `stripFile` pass through
unchanged. Match the kind, never the message:

```jennifer
try {
    def e as exif.Exif init exif.read($data);
} catch (err) {
    if ($err.kind != "exif") {
        throw $err;
    }
    def bad as exif.ExifError init $err;
    io.printf("not readable at byte %d: %s\n", $bad.offset, $bad.message);
}
```
