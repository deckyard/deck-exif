# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.28.0

# exif - whole images: detect the container, read, write and strip EXIF,
# and the file helpers.
# Spliced into exif.j via include - not a standalone module.

/**
 * Where a container keeps its EXIF, or would put it.
 *
 * @field found {bool} whether the image has an EXIF segment or chunk
 * @field start {int} the first byte of the segment or chunk
 * @field end {int} the first byte after it (padding included)
 * @field payload {int} the first byte of the TIFF payload
 * @field payloadEnd {int} the first byte after the payload
 * @field insertAt {int} where a new segment or chunk goes when there is none
 * @field extended {bool} WebP only: the file has a `VP8X` chunk
 */
def struct Segment {
    found as bool,
    start as int,
    end as int,
    payload as int,
    payloadEnd as int,
    insertAt as int,
    extended as bool
};

/**
 * A `Segment` for an image without EXIF.
 *
 * @param insertAt {int} where a new segment would go
 * @return {Segment} not found
 */
func noSegment(insertAt as int) {
    return Segment{
        found: false,
        start: 0,
        end: 0,
        payload: 0,
        payloadEnd: 0,
        insertAt: $insertAt,
        extended: false
    };
}

/**
 * Replace the segment (or insert at `insertAt` when there is none) with
 * `piece`, copying everything else.
 *
 * @param data {bytes} the image
 * @param seg {Segment} the segment
 * @param piece {bytes} the new segment, empty to remove
 * @return {bytes} the new image
 */
func cut(data as bytes, seg as Segment, piece as bytes) {
    def from as int init $seg.insertAt;
    def to2 as int init $seg.insertAt;
    if ($seg.found) {
        $from = $seg.start;
        $to2 = $seg.end;
    }
    return binary.join([$data[0..$from], $piece, $data[$to2..len($data)]]);
}

/**
 * The container of an image, from its first bytes.
 *
 * @param data {bytes} the image
 * @return {string} `"jpeg"`, `"png"` or `"webp"`
 * @throws {ExifError} for anything else
 */
export func format(data as bytes) {
    if (len($data) >= 3 and $data[0] == 0xFF and $data[1] == 0xD8 and $data[2] == 0xFF) {
        return "jpeg";
    }
    def png as bytes init binary.make(1, 0x89);
    def sig as bytes init binary.concat($png, ascii("PNG\r\n"));
    $sig[] = 0x1A;
    $sig[] = 0x0A;
    if (binary.startsWith($data, $sig)) {
        return "png";
    }
    if (binary.startsWith($data, ascii("RIFF")) and hasAt($data, 8, ascii("WEBP"))) {
        return "webp";
    }
    failAt("not a JPEG, PNG or WebP image", 0);
}

/**
 * Locate the EXIF of an image of any supported container.
 *
 * @param data {bytes} the image
 * @param kind {string} its container, from `format`
 * @return {Segment} where the EXIF is
 * @throws {ExifError} for a malformed container
 */
func locate(data as bytes, kind as string) {
    match ($kind) {
        when "jpeg" { return jpegLocate($data); }
        when "png" { return pngLocate($data); }
        else { return webpLocate($data); }
    }
}

/**
 * The image with its EXIF payload replaced; an empty payload removes it.
 *
 * @param data {bytes} the image
 * @param payload {bytes} the new payload
 * @return {bytes} the new image
 * @throws {ExifError} for a malformed container, or a payload the container cannot hold
 */
func replace(data as bytes, payload as bytes) {
    def kind as string init format($data);
    def seg as Segment init locate($data, $kind);
    match ($kind) {
        when "jpeg" { return jpegReplace($data, $seg, $payload); }
        when "png" { return pngReplace($data, $seg, $payload); }
        else { return webpReplace($data, $seg, $payload); }
    }
}

/**
 * Whether an image carries EXIF.
 *
 * @param data {bytes} a JPEG, PNG or WebP image
 * @return {bool} true when it has an EXIF segment or chunk
 * @throws {ExifError} for an unknown or malformed container
 */
export func hasExif(data as bytes) {
    return locate($data, format($data)).found;
}

/**
 * Read the EXIF of an image. An image without EXIF gives an empty `Exif`
 * (big-endian), which `write` can fill.
 *
 * @param data {bytes} a JPEG, PNG or WebP image
 * @return {Exif} the metadata
 * @throws {ExifError} kind "exif" for an unknown or malformed image or EXIF, `offset` counted in `data`
 * @throws {Error} kind "limit" when a default cap is reached
 * @example
 *   def e as exif.Exif init exif.read(fs.readBytes("photo.jpg"));
 *   io.printf("%s\n", exif.text($e, "Model"));
 */
export func read(data as bytes) {
    return readWith($data, Options{maxBytes: 0, maxEntries: 0, maxValueBytes: 0});
}

/**
 * `read` with lowered caps.
 *
 * @param data {bytes} a JPEG, PNG or WebP image
 * @param options {Options} the caps; a zero field keeps the default
 * @return {Exif} the metadata
 * @throws {ExifError} kind "exif" for a malformed image or EXIF, or a bad option
 * @throws {Error} kind "limit" when a cap is reached
 */
export func readWith(data as bytes, options as Options) {
    capsOf($options);
    def seg as Segment init locate($data, format($data));
    if (not $seg.found) {
        return empty("be");
    }
    return parseAt($data, $seg.payload, $seg.payloadEnd, $options);
}

/**
 * Read the EXIF of an image file.
 *
 * @param path {string} the file
 * @return {Exif} the metadata
 * @throws {ExifError} kind "exif" as `read`
 * @throws {Error} the `fs` error when the file cannot be read
 */
export func readFile(path as string) {
    return read(fs.readBytes($path));
}

/**
 * The image with `x` as its EXIF: the old EXIF segment or chunk replaced
 * (or a new one added), every other byte as it was.
 *
 * @param data {bytes} a JPEG, PNG or WebP image
 * @param x {Exif} the metadata to write
 * @return {bytes} the new image
 * @throws {ExifError} for a malformed image, an entry that does not check out, or a payload too large for the container
 * @throws {Error} kind "limit" for metadata over a default cap of `read`, which could not read it back
 * @example
 *   def e as exif.Exif init exif.removeGps(exif.read($img));
 *   $img = exif.write($img, $e);
 */
export func write(data as bytes, x as Exif) {
    return replace($data, render($x));
}

/**
 * The image without EXIF. An image that has none comes back unchanged.
 *
 * @param data {bytes} a JPEG, PNG or WebP image
 * @return {bytes} the image without its EXIF segment or chunk
 * @throws {ExifError} for an unknown or malformed image
 */
export func strip(data as bytes) {
    return replace($data, binary.make(0));
}

/**
 * Replace a file's content atomically: write a temporary file beside it,
 * then rename it over.
 *
 * @param path {string} the file
 * @param data {bytes} the new content
 * @throws {Error} the `fs` error when writing or renaming fails; the temporary file is removed
 */
func replaceFile(path as string, data as bytes) {
    def temp as string init $path + "." + uuid.v4() + ".exiftmp";
    errdefer removeQuietly($temp);
    fs.writeNew($temp, $data);
    fs.rename($temp, $path);
}

/**
 * Remove a file, ignoring failure: the cleanup of a write that already failed.
 *
 * @param path {string} the file
 */
func removeQuietly(path as string) {
    try {
        fs.remove($path);
    } catch (e) {
        return;
    }
}

/**
 * Write `x` into an image file, replacing it atomically.
 *
 * @param path {string} a JPEG, PNG or WebP file
 * @param x {Exif} the metadata
 * @throws {ExifError} as `write`
 * @throws {Error} the `fs` error when the file cannot be read or replaced
 */
export func writeFile(path as string, x as Exif) {
    replaceFile($path, write(fs.readBytes($path), $x));
}

/**
 * Remove the EXIF of an image file, replacing it atomically.
 *
 * @param path {string} a JPEG, PNG or WebP file
 * @throws {ExifError} as `strip`
 * @throws {Error} the `fs` error when the file cannot be read or replaced
 */
export func stripFile(path as string) {
    replaceFile($path, strip(fs.readBytes($path)));
}
