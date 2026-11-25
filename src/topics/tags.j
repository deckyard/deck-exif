# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.28.0

# exif - IFD names, field types and the tag table.
# Spliced into exif.j via include - not a standalone module.

/** IFD0, the main image: camera, software, orientation, resolution. */
export def const IFD0 as string init "ifd0";

/** The Exif IFD (pointer tag `0x8769` in IFD0): exposure, lens, dates. */
export def const IFD_EXIF as string init "exif";

/** The GPS IFD (pointer tag `0x8825` in IFD0). */
export def const IFD_GPS as string init "gps";

/** The Interoperability IFD (pointer tag `0xA005` in the Exif IFD). */
export def const IFD_INTEROP as string init "interop";

/** IFD1, the thumbnail image. */
export def const IFD1 as string init "ifd1";

/** Field type 1: unsigned 8-bit integers. */
export def const TYPE_BYTE as int init 1;

/** Field type 2: NUL-terminated 7-bit text. */
export def const TYPE_ASCII as int init 2;

/** Field type 3: unsigned 16-bit integers. */
export def const TYPE_SHORT as int init 3;

/** Field type 4: unsigned 32-bit integers. */
export def const TYPE_LONG as int init 4;

/** Field type 5: two unsigned 32-bit integers, numerator and denominator. */
export def const TYPE_RATIONAL as int init 5;

/** Field type 6: signed 8-bit integers. */
export def const TYPE_SBYTE as int init 6;

/** Field type 7: bytes whose meaning the tag defines. */
export def const TYPE_UNDEFINED as int init 7;

/** Field type 8: signed 16-bit integers. */
export def const TYPE_SSHORT as int init 8;

/** Field type 9: signed 32-bit integers. */
export def const TYPE_SLONG as int init 9;

/** Field type 10: two signed 32-bit integers, numerator and denominator. */
export def const TYPE_SRATIONAL as int init 10;

/** Field type 11: IEEE 754 single-precision floats. */
export def const TYPE_FLOAT as int init 11;

/** Field type 12: IEEE 754 double-precision floats. */
export def const TYPE_DOUBLE as int init 12;

/** In the table: `SHORT`, or `LONG` when a value needs it. */
def const TYPE_SHORT_OR_LONG as int init 0;

/** The five IFDs, in the order the writer lays them out. */
def const IFDS as list of string init ["ifd0", "exif", "interop", "gps", "ifd1"];

/** The Exif IFD pointer, in IFD0. */
def const TAG_EXIF_POINTER as int init 0x8769;

/** The GPS IFD pointer, in IFD0. */
def const TAG_GPS_POINTER as int init 0x8825;

/** The Interoperability IFD pointer, in the Exif IFD. */
def const TAG_INTEROP_POINTER as int init 0xA005;

/** The thumbnail's offset (JPEGInterchangeFormat), in IFD1. */
def const TAG_THUMB_OFFSET as int init 0x0201;

/** The thumbnail's length (JPEGInterchangeFormatLength), in IFD1. */
def const TAG_THUMB_LENGTH as int init 0x0202;

/** StripOffsets: where uncompressed image data starts. */
def const TAG_STRIP_OFFSETS as int init 0x0111;

/** TileOffsets: where tiled image data starts. */
def const TAG_TILE_OFFSETS as int init 0x0144;

/**
 * One known tag.
 *
 * @field id {int} the tag number
 * @field name {string} its name in the Exif 2.32 standard
 * @field group {string} `"tiff"` (IFD0 and IFD1), `"exif"`, `"gps"` or `"interop"`
 * @field type {int} the field type the setters write; 0 for `SHORT` or `LONG`
 */
def struct TagDef {
    id as int,
    name as string,
    group as string,
    type as int
};

/**
 * A resolved tag reference.
 *
 * @field ifd {string} the IFD name
 * @field id {int} the tag number
 * @field type {int} the type from the table, -1 for a tag outside it
 */
def struct TagRef {
    ifd as string,
    id as int,
    type as int
};

/** The tags the deck knows by name. */
def const TAGS as list of TagDef init [
    TagDef{id: 0x0100, name: "ImageWidth", group: "tiff", type: 0},
    TagDef{id: 0x0101, name: "ImageLength", group: "tiff", type: 0},
    TagDef{id: 0x0102, name: "BitsPerSample", group: "tiff", type: 3},
    TagDef{id: 0x0103, name: "Compression", group: "tiff", type: 3},
    TagDef{id: 0x0106, name: "PhotometricInterpretation", group: "tiff", type: 3},
    TagDef{id: 0x010E, name: "ImageDescription", group: "tiff", type: 2},
    TagDef{id: 0x010F, name: "Make", group: "tiff", type: 2},
    TagDef{id: 0x0110, name: "Model", group: "tiff", type: 2},
    TagDef{id: 0x0112, name: "Orientation", group: "tiff", type: 3},
    TagDef{id: 0x0115, name: "SamplesPerPixel", group: "tiff", type: 3},
    TagDef{id: 0x0116, name: "RowsPerStrip", group: "tiff", type: 0},
    TagDef{id: 0x0117, name: "StripByteCounts", group: "tiff", type: 0},
    TagDef{id: 0x011A, name: "XResolution", group: "tiff", type: 5},
    TagDef{id: 0x011B, name: "YResolution", group: "tiff", type: 5},
    TagDef{id: 0x011C, name: "PlanarConfiguration", group: "tiff", type: 3},
    TagDef{id: 0x0128, name: "ResolutionUnit", group: "tiff", type: 3},
    TagDef{id: 0x012D, name: "TransferFunction", group: "tiff", type: 3},
    TagDef{id: 0x0131, name: "Software", group: "tiff", type: 2},
    TagDef{id: 0x0132, name: "DateTime", group: "tiff", type: 2},
    TagDef{id: 0x013B, name: "Artist", group: "tiff", type: 2},
    TagDef{id: 0x013E, name: "WhitePoint", group: "tiff", type: 5},
    TagDef{id: 0x013F, name: "PrimaryChromaticities", group: "tiff", type: 5},
    TagDef{id: 0x0211, name: "YCbCrCoefficients", group: "tiff", type: 5},
    TagDef{id: 0x0212, name: "YCbCrSubSampling", group: "tiff", type: 3},
    TagDef{id: 0x0213, name: "YCbCrPositioning", group: "tiff", type: 3},
    TagDef{id: 0x0214, name: "ReferenceBlackWhite", group: "tiff", type: 5},
    TagDef{id: 0x8298, name: "Copyright", group: "tiff", type: 2},
    TagDef{id: 0x9C9B, name: "XPTitle", group: "tiff", type: 1},
    TagDef{id: 0x9C9C, name: "XPComment", group: "tiff", type: 1},
    TagDef{id: 0x9C9D, name: "XPAuthor", group: "tiff", type: 1},
    TagDef{id: 0x9C9E, name: "XPKeywords", group: "tiff", type: 1},
    TagDef{id: 0x9C9F, name: "XPSubject", group: "tiff", type: 1},
    TagDef{id: 0x829A, name: "ExposureTime", group: "exif", type: 5},
    TagDef{id: 0x829D, name: "FNumber", group: "exif", type: 5},
    TagDef{id: 0x8822, name: "ExposureProgram", group: "exif", type: 3},
    TagDef{id: 0x8824, name: "SpectralSensitivity", group: "exif", type: 2},
    TagDef{id: 0x8827, name: "PhotographicSensitivity", group: "exif", type: 3},
    TagDef{id: 0x8828, name: "OECF", group: "exif", type: 7},
    TagDef{id: 0x8830, name: "SensitivityType", group: "exif", type: 3},
    TagDef{id: 0x8832, name: "RecommendedExposureIndex", group: "exif", type: 4},
    TagDef{id: 0x9000, name: "ExifVersion", group: "exif", type: 7},
    TagDef{id: 0x9003, name: "DateTimeOriginal", group: "exif", type: 2},
    TagDef{id: 0x9004, name: "DateTimeDigitized", group: "exif", type: 2},
    TagDef{id: 0x9010, name: "OffsetTime", group: "exif", type: 2},
    TagDef{id: 0x9011, name: "OffsetTimeOriginal", group: "exif", type: 2},
    TagDef{id: 0x9012, name: "OffsetTimeDigitized", group: "exif", type: 2},
    TagDef{id: 0x9101, name: "ComponentsConfiguration", group: "exif", type: 7},
    TagDef{id: 0x9102, name: "CompressedBitsPerPixel", group: "exif", type: 5},
    TagDef{id: 0x9201, name: "ShutterSpeedValue", group: "exif", type: 10},
    TagDef{id: 0x9202, name: "ApertureValue", group: "exif", type: 5},
    TagDef{id: 0x9203, name: "BrightnessValue", group: "exif", type: 10},
    TagDef{id: 0x9204, name: "ExposureBiasValue", group: "exif", type: 10},
    TagDef{id: 0x9205, name: "MaxApertureValue", group: "exif", type: 5},
    TagDef{id: 0x9206, name: "SubjectDistance", group: "exif", type: 5},
    TagDef{id: 0x9207, name: "MeteringMode", group: "exif", type: 3},
    TagDef{id: 0x9208, name: "LightSource", group: "exif", type: 3},
    TagDef{id: 0x9209, name: "Flash", group: "exif", type: 3},
    TagDef{id: 0x920A, name: "FocalLength", group: "exif", type: 5},
    TagDef{id: 0x9214, name: "SubjectArea", group: "exif", type: 3},
    TagDef{id: 0x927C, name: "MakerNote", group: "exif", type: 7},
    TagDef{id: 0x9286, name: "UserComment", group: "exif", type: 7},
    TagDef{id: 0x9290, name: "SubSecTime", group: "exif", type: 2},
    TagDef{id: 0x9291, name: "SubSecTimeOriginal", group: "exif", type: 2},
    TagDef{id: 0x9292, name: "SubSecTimeDigitized", group: "exif", type: 2},
    TagDef{id: 0xA000, name: "FlashpixVersion", group: "exif", type: 7},
    TagDef{id: 0xA001, name: "ColorSpace", group: "exif", type: 3},
    TagDef{id: 0xA002, name: "PixelXDimension", group: "exif", type: 0},
    TagDef{id: 0xA003, name: "PixelYDimension", group: "exif", type: 0},
    TagDef{id: 0xA004, name: "RelatedSoundFile", group: "exif", type: 2},
    TagDef{id: 0xA20B, name: "FlashEnergy", group: "exif", type: 5},
    TagDef{id: 0xA20E, name: "FocalPlaneXResolution", group: "exif", type: 5},
    TagDef{id: 0xA20F, name: "FocalPlaneYResolution", group: "exif", type: 5},
    TagDef{id: 0xA210, name: "FocalPlaneResolutionUnit", group: "exif", type: 3},
    TagDef{id: 0xA214, name: "SubjectLocation", group: "exif", type: 3},
    TagDef{id: 0xA215, name: "ExposureIndex", group: "exif", type: 5},
    TagDef{id: 0xA217, name: "SensingMethod", group: "exif", type: 3},
    TagDef{id: 0xA300, name: "FileSource", group: "exif", type: 7},
    TagDef{id: 0xA301, name: "SceneType", group: "exif", type: 7},
    TagDef{id: 0xA302, name: "CFAPattern", group: "exif", type: 7},
    TagDef{id: 0xA401, name: "CustomRendered", group: "exif", type: 3},
    TagDef{id: 0xA402, name: "ExposureMode", group: "exif", type: 3},
    TagDef{id: 0xA403, name: "WhiteBalance", group: "exif", type: 3},
    TagDef{id: 0xA404, name: "DigitalZoomRatio", group: "exif", type: 5},
    TagDef{id: 0xA405, name: "FocalLengthIn35mmFilm", group: "exif", type: 3},
    TagDef{id: 0xA406, name: "SceneCaptureType", group: "exif", type: 3},
    TagDef{id: 0xA407, name: "GainControl", group: "exif", type: 3},
    TagDef{id: 0xA408, name: "Contrast", group: "exif", type: 3},
    TagDef{id: 0xA409, name: "Saturation", group: "exif", type: 3},
    TagDef{id: 0xA40A, name: "Sharpness", group: "exif", type: 3},
    TagDef{id: 0xA40C, name: "SubjectDistanceRange", group: "exif", type: 3},
    TagDef{id: 0xA420, name: "ImageUniqueID", group: "exif", type: 2},
    TagDef{id: 0xA430, name: "CameraOwnerName", group: "exif", type: 2},
    TagDef{id: 0xA431, name: "BodySerialNumber", group: "exif", type: 2},
    TagDef{id: 0xA432, name: "LensSpecification", group: "exif", type: 5},
    TagDef{id: 0xA433, name: "LensMake", group: "exif", type: 2},
    TagDef{id: 0xA434, name: "LensModel", group: "exif", type: 2},
    TagDef{id: 0xA435, name: "LensSerialNumber", group: "exif", type: 2},
    TagDef{id: 0xA500, name: "Gamma", group: "exif", type: 5},
    TagDef{id: 0x0000, name: "GPSVersionID", group: "gps", type: 1},
    TagDef{id: 0x0001, name: "GPSLatitudeRef", group: "gps", type: 2},
    TagDef{id: 0x0002, name: "GPSLatitude", group: "gps", type: 5},
    TagDef{id: 0x0003, name: "GPSLongitudeRef", group: "gps", type: 2},
    TagDef{id: 0x0004, name: "GPSLongitude", group: "gps", type: 5},
    TagDef{id: 0x0005, name: "GPSAltitudeRef", group: "gps", type: 1},
    TagDef{id: 0x0006, name: "GPSAltitude", group: "gps", type: 5},
    TagDef{id: 0x0007, name: "GPSTimeStamp", group: "gps", type: 5},
    TagDef{id: 0x0008, name: "GPSSatellites", group: "gps", type: 2},
    TagDef{id: 0x0009, name: "GPSStatus", group: "gps", type: 2},
    TagDef{id: 0x000A, name: "GPSMeasureMode", group: "gps", type: 2},
    TagDef{id: 0x000B, name: "GPSDOP", group: "gps", type: 5},
    TagDef{id: 0x000C, name: "GPSSpeedRef", group: "gps", type: 2},
    TagDef{id: 0x000D, name: "GPSSpeed", group: "gps", type: 5},
    TagDef{id: 0x000E, name: "GPSTrackRef", group: "gps", type: 2},
    TagDef{id: 0x000F, name: "GPSTrack", group: "gps", type: 5},
    TagDef{id: 0x0010, name: "GPSImgDirectionRef", group: "gps", type: 2},
    TagDef{id: 0x0011, name: "GPSImgDirection", group: "gps", type: 5},
    TagDef{id: 0x0012, name: "GPSMapDatum", group: "gps", type: 2},
    TagDef{id: 0x0013, name: "GPSDestLatitudeRef", group: "gps", type: 2},
    TagDef{id: 0x0014, name: "GPSDestLatitude", group: "gps", type: 5},
    TagDef{id: 0x0015, name: "GPSDestLongitudeRef", group: "gps", type: 2},
    TagDef{id: 0x0016, name: "GPSDestLongitude", group: "gps", type: 5},
    TagDef{id: 0x0017, name: "GPSDestBearingRef", group: "gps", type: 2},
    TagDef{id: 0x0018, name: "GPSDestBearing", group: "gps", type: 5},
    TagDef{id: 0x0019, name: "GPSDestDistanceRef", group: "gps", type: 2},
    TagDef{id: 0x001A, name: "GPSDestDistance", group: "gps", type: 5},
    TagDef{id: 0x001B, name: "GPSProcessingMethod", group: "gps", type: 7},
    TagDef{id: 0x001C, name: "GPSAreaInformation", group: "gps", type: 7},
    TagDef{id: 0x001D, name: "GPSDateStamp", group: "gps", type: 2},
    TagDef{id: 0x001E, name: "GPSDifferential", group: "gps", type: 3},
    TagDef{id: 0x001F, name: "GPSHPositioningError", group: "gps", type: 5},
    TagDef{id: 0x0001, name: "InteroperabilityIndex", group: "interop", type: 2},
    TagDef{id: 0x0002, name: "InteroperabilityVersion", group: "interop", type: 7},
    TagDef{id: 0x1000, name: "RelatedImageFileFormat", group: "interop", type: 2},
    TagDef{id: 0x1001, name: "RelatedImageWidth", group: "interop", type: 0},
    TagDef{id: 0x1002, name: "RelatedImageLength", group: "interop", type: 0}
];

/**
 * The table group an IFD's tags come from.
 *
 * @param ifd {string} an IFD name
 * @return {string} `"tiff"` for IFD0 and IFD1, else the IFD name
 */
func groupOf(ifd as string) {
    if ($ifd == IFD0 or $ifd == IFD1) {
        return "tiff";
    }
    return $ifd;
}

/**
 * Check an IFD name.
 *
 * @param ifd {string} the name to check
 * @throws {ExifError} when it is not one of the five
 */
func checkIfd(ifd as string) {
    if (not lists.contains(IFDS, $ifd)) {
        fail("unknown IFD \"" + $ifd + "\"; known: ifd0, exif, interop, gps, ifd1");
    }
}

/**
 * The bytes one value of a field type takes.
 *
 * @param type {int} a field type, 1-12
 * @return {int} 1, 2, 4 or 8; 0 for a type outside 1-12
 */
func typeSize(type as int) {
    match ($type) {
        when 1, 2, 6, 7 { return 1; }
        when 3, 8 { return 2; }
        when 4, 9, 11 { return 4; }
        when 5, 10, 12 { return 8; }
        else { return 0; }
    }
}

/**
 * The name of a tag in the given IFD.
 *
 * @param ifd {string} the IFD name (`IFD0`, `IFD_EXIF`, ...)
 * @param tag {int} the tag number
 * @return {string} the standard name, or `""` for a tag outside the deck's table
 * @throws {ExifError} for an unknown IFD name
 * @example
 *   exif.tagName(exif.IFD_GPS, 2);   # "GPSLatitude"
 */
export func tagName(ifd as string, tag as int) {
    checkIfd($ifd);
    def group as string init groupOf($ifd);
    for (def t in TAGS) {
        if ($t.id == $tag and $t.group == $group) {
            return $t.name;
        }
    }
    return "";
}

/**
 * The tag's type from the table, or -1.
 *
 * @param ifd {string} the IFD name
 * @param id {int} the tag number
 * @return {int} the table type (0 for `SHORT` or `LONG`), -1 when the tag is not in the table
 */
func tableType(ifd as string, id as int) {
    def group as string init groupOf($ifd);
    for (def t in TAGS) {
        if ($t.id == $id and $t.group == $group) {
            return $t.type;
        }
    }
    return -1;
}

/**
 * Resolve a tag reference: `"Make"`, `"ifd1:XResolution"`, `"gps:0x0002"`
 * or `"exif:42036"`.
 *
 * @param tag {string} the reference
 * @return {TagRef} its IFD, number and table type
 * @throws {ExifError} for an unknown name, IFD or a number outside 0-65535
 */
func resolve(tag as string) {
    def ifd as string init "";
    def name as string init $tag;
    def colon as int init strings.indexOf($tag, ":");
    if ($colon >= 0) {
        $ifd = $tag[0..$colon];
        $name = $tag[$colon + 1..len($tag)];
        checkIfd($ifd);
        if (regex.matches('^(0x[0-9A-Fa-f]{1,4}|[0-9]{1,5})$', $name)) {
            def id as int init 0;
            if (strings.startsWith($name, "0x")) {
                $id = convert.toInt($name[2..len($name)], 16);
            } else {
                $id = convert.toInt($name);
            }
            if ($id > 65535) {
                fail("tag number " + $name + " is above 65535");
            }
            return TagRef{ifd: $ifd, id: $id, type: tableType($ifd, $id)};
        }
    }
    for (def t in TAGS) {
        if ($t.name == $name) {
            return refOf($t, $ifd);
        }
    }
    fail("unknown tag \"" + $tag + "\"; name a tag by number as \"ifd:0x1234\"");
}

/**
 * A table tag as a reference, in the IFD the caller named or its default one.
 *
 * @param t {TagDef} the table entry
 * @param ifd {string} the IFD from an `ifd:` prefix, `""` for none
 * @return {TagRef} the reference
 * @throws {ExifError} when the tag does not belong in the named IFD
 */
func refOf(t as TagDef, ifd as string) {
    if ($ifd == "") {
        if ($t.group == "tiff") {
            return TagRef{ifd: IFD0, id: $t.id, type: $t.type};
        }
        return TagRef{ifd: $t.group, id: $t.id, type: $t.type};
    }
    if (groupOf($ifd) != $t.group) {
        fail("tag " + $t.name + " does not belong in IFD " + $ifd);
    }
    return TagRef{ifd: $ifd, id: $t.id, type: $t.type};
}
