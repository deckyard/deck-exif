<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# Reading, changing and removing

## Reading

`read` takes the image bytes; the container (JPEG, PNG, WebP) is detected
from them. An image without EXIF gives an empty `Exif`.

```jennifer
import "@deckyard/exif/" as exif;

def img as bytes init fs.readBytes("photo.jpg");
def e as exif.Exif init exif.read($img);
for (def entry in $e.entries) {
    io.printf("%s %s = %s\n", $entry.ifd, exif.tagName($entry.ifd, $entry.tag), exif.describe($entry));
}
```

Tags are named by a string: `"Model"`, `"ifd1:XResolution"` for the
thumbnail's IFD, or `"exif:0xA460"` by number. The typed readers throw when
the tag is absent, so test with `has` first where it may be:

```jennifer
if (exif.has($e, "FNumber")) {
    io.printf("f/%f\n", exif.floats($e, "FNumber")[0]);
}
def iso as list of int init exif.ints($e, "PhotographicSensitivity");
def exposure as list of exif.Rational init exif.rationals($e, "ExposureTime");
def comment as bytes init exif.raw($e, "UserComment");
```

`text` decodes an `ASCII` tag as UTF-8 and throws when it is not; `raw`
gives the stored bytes for anything a camera wrote in another encoding.

### Orientation, location, time

```jennifer
def turn as int init exif.orientation($e);           # 1 to 8
if (exif.hasGps($e)) {
    def g as exif.Gps init exif.gps($e);
    io.printf("%f, %f\n", $g.latitude, $g.longitude);
}
def taken as time.Time init exif.dateTime($e, "DateTimeOriginal", time.zone(3600, "CET"));
def fix as time.Time init exif.gpsTime($e);           # UTC
```

EXIF date and time tags are the camera's local time. `dateTime` uses the
`OffsetTimeOriginal` (or `OffsetTime`, `OffsetTimeDigitized`) tag when the
image has one, and the zone you pass otherwise.

## Changing

The setters pick the field type from the [tag table](tags.md) and keep the
entries in order:

```jennifer
$e = exif.setText($e, "Artist", "Ada Lovelace");
$e = exif.setText($e, "Copyright", "(C) 2026 Ada Lovelace");
$e = exif.setInts($e, "Orientation", [1]);
$e = exif.setRationals($e, "ExposureTime", [exif.Rational{num: 1, den: 250}]);
$e = exif.setGps($e, 48.2082, 16.3738);
$e = exif.remove($e, "Software");
fs.writeBytes("photo.jpg", exif.write($img, $e));
```

`writeFile(path, e)` does the same on a file and replaces it atomically. A
tag outside the table, or a type the setters do not choose, goes through
`makeEntry`:

```jennifer
def entry as exif.Entry init exif.makeEntry("exif:0xA460", exif.TYPE_SHORT, exif.Value.Ints{values: [1]});
$e = exif.set($e, $entry);
```

`write` re-serialises the whole EXIF structure. Two consequences:

- The MakerNote is kept byte for byte, but it may move. Vendors that store
  offsets inside it relative to the TIFF™ header (Canon™, Sony™, older
  Olympus™) then point at the wrong bytes, and their tools may no longer
  read it. Remove it (`exif.remove($e, "MakerNote")`) when that matters
  more than keeping it.
- A JPEG holds at most 65,527 bytes of EXIF; a larger one (a big thumbnail
  or MakerNote) is refused.

## Removing

```jennifer
fs.writeBytes("clean.jpg", exif.strip($img));             # all EXIF
$e = exif.removeGps($e);                                   # the location
$e = exif.removeThumbnail($e);                             # the preview image
```

The thumbnail is worth removing when sharing a cropped or edited photo: it
still shows the original. `strip` removes EXIF only; XMP™ and IPTC metadata
in their own segments stay. [examples/privacy.j](https://github.com/deckyard/deck-exif/blob/main/examples/privacy.j)
removes location, thumbnail and serial numbers.
