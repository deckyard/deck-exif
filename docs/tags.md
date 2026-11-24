<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# Tag table

The tags the deck knows by name, with the field type the setters write.
A bare name finds its IFD here; the TIFF™ tags default to IFD0 and reach
IFD1 as `"ifd1:Name"`. Any other tag is named by IFD and number
(`"exif:0xA460"`) and set with `makeEntry`. Names follow Exif 2.32
(`PhotographicSensitivity` is the ISO speed).

The pointer tags `0x8769` (Exif IFD), `0x8825` (GPS IFD), `0xA005`
(Interoperability IFD) and IFD1's `0x0201` / `0x0202` (thumbnail offset and
length) are not entries: the writer computes them.

## IFD0 and IFD1 (`ifd0`, `ifd1`)

| Tag | Name | Type |
|---|---|---|
| `0x0100` | `ImageWidth` | SHORT or LONG |
| `0x0101` | `ImageLength` | SHORT or LONG |
| `0x0102` | `BitsPerSample` | SHORT |
| `0x0103` | `Compression` | SHORT |
| `0x0106` | `PhotometricInterpretation` | SHORT |
| `0x010E` | `ImageDescription` | ASCII |
| `0x010F` | `Make` | ASCII |
| `0x0110` | `Model` | ASCII |
| `0x0112` | `Orientation` | SHORT |
| `0x0115` | `SamplesPerPixel` | SHORT |
| `0x0116` | `RowsPerStrip` | SHORT or LONG |
| `0x0117` | `StripByteCounts` | SHORT or LONG |
| `0x011A` | `XResolution` | RATIONAL |
| `0x011B` | `YResolution` | RATIONAL |
| `0x011C` | `PlanarConfiguration` | SHORT |
| `0x0128` | `ResolutionUnit` | SHORT |
| `0x012D` | `TransferFunction` | SHORT |
| `0x0131` | `Software` | ASCII |
| `0x0132` | `DateTime` | ASCII |
| `0x013B` | `Artist` | ASCII |
| `0x013E` | `WhitePoint` | RATIONAL |
| `0x013F` | `PrimaryChromaticities` | RATIONAL |
| `0x0211` | `YCbCrCoefficients` | RATIONAL |
| `0x0212` | `YCbCrSubSampling` | SHORT |
| `0x0213` | `YCbCrPositioning` | SHORT |
| `0x0214` | `ReferenceBlackWhite` | RATIONAL |
| `0x8298` | `Copyright` | ASCII |
| `0x9C9B` | `XPTitle` | BYTE |
| `0x9C9C` | `XPComment` | BYTE |
| `0x9C9D` | `XPAuthor` | BYTE |
| `0x9C9E` | `XPKeywords` | BYTE |
| `0x9C9F` | `XPSubject` | BYTE |

## Exif IFD (`exif`)

| Tag | Name | Type |
|---|---|---|
| `0x829A` | `ExposureTime` | RATIONAL |
| `0x829D` | `FNumber` | RATIONAL |
| `0x8822` | `ExposureProgram` | SHORT |
| `0x8824` | `SpectralSensitivity` | ASCII |
| `0x8827` | `PhotographicSensitivity` | SHORT |
| `0x8828` | `OECF` | UNDEFINED |
| `0x8830` | `SensitivityType` | SHORT |
| `0x8832` | `RecommendedExposureIndex` | LONG |
| `0x9000` | `ExifVersion` | UNDEFINED |
| `0x9003` | `DateTimeOriginal` | ASCII |
| `0x9004` | `DateTimeDigitized` | ASCII |
| `0x9010` | `OffsetTime` | ASCII |
| `0x9011` | `OffsetTimeOriginal` | ASCII |
| `0x9012` | `OffsetTimeDigitized` | ASCII |
| `0x9101` | `ComponentsConfiguration` | UNDEFINED |
| `0x9102` | `CompressedBitsPerPixel` | RATIONAL |
| `0x9201` | `ShutterSpeedValue` | SRATIONAL |
| `0x9202` | `ApertureValue` | RATIONAL |
| `0x9203` | `BrightnessValue` | SRATIONAL |
| `0x9204` | `ExposureBiasValue` | SRATIONAL |
| `0x9205` | `MaxApertureValue` | RATIONAL |
| `0x9206` | `SubjectDistance` | RATIONAL |
| `0x9207` | `MeteringMode` | SHORT |
| `0x9208` | `LightSource` | SHORT |
| `0x9209` | `Flash` | SHORT |
| `0x920A` | `FocalLength` | RATIONAL |
| `0x9214` | `SubjectArea` | SHORT |
| `0x927C` | `MakerNote` | UNDEFINED |
| `0x9286` | `UserComment` | UNDEFINED |
| `0x9290` | `SubSecTime` | ASCII |
| `0x9291` | `SubSecTimeOriginal` | ASCII |
| `0x9292` | `SubSecTimeDigitized` | ASCII |
| `0xA000` | `FlashpixVersion` | UNDEFINED |
| `0xA001` | `ColorSpace` | SHORT |
| `0xA002` | `PixelXDimension` | SHORT or LONG |
| `0xA003` | `PixelYDimension` | SHORT or LONG |
| `0xA004` | `RelatedSoundFile` | ASCII |
| `0xA20B` | `FlashEnergy` | RATIONAL |
| `0xA20E` | `FocalPlaneXResolution` | RATIONAL |
| `0xA20F` | `FocalPlaneYResolution` | RATIONAL |
| `0xA210` | `FocalPlaneResolutionUnit` | SHORT |
| `0xA214` | `SubjectLocation` | SHORT |
| `0xA215` | `ExposureIndex` | RATIONAL |
| `0xA217` | `SensingMethod` | SHORT |
| `0xA300` | `FileSource` | UNDEFINED |
| `0xA301` | `SceneType` | UNDEFINED |
| `0xA302` | `CFAPattern` | UNDEFINED |
| `0xA401` | `CustomRendered` | SHORT |
| `0xA402` | `ExposureMode` | SHORT |
| `0xA403` | `WhiteBalance` | SHORT |
| `0xA404` | `DigitalZoomRatio` | RATIONAL |
| `0xA405` | `FocalLengthIn35mmFilm` | SHORT |
| `0xA406` | `SceneCaptureType` | SHORT |
| `0xA407` | `GainControl` | SHORT |
| `0xA408` | `Contrast` | SHORT |
| `0xA409` | `Saturation` | SHORT |
| `0xA40A` | `Sharpness` | SHORT |
| `0xA40C` | `SubjectDistanceRange` | SHORT |
| `0xA420` | `ImageUniqueID` | ASCII |
| `0xA430` | `CameraOwnerName` | ASCII |
| `0xA431` | `BodySerialNumber` | ASCII |
| `0xA432` | `LensSpecification` | RATIONAL |
| `0xA433` | `LensMake` | ASCII |
| `0xA434` | `LensModel` | ASCII |
| `0xA435` | `LensSerialNumber` | ASCII |
| `0xA500` | `Gamma` | RATIONAL |

## GPS IFD (`gps`)

| Tag | Name | Type |
|---|---|---|
| `0x0000` | `GPSVersionID` | BYTE |
| `0x0001` | `GPSLatitudeRef` | ASCII |
| `0x0002` | `GPSLatitude` | RATIONAL |
| `0x0003` | `GPSLongitudeRef` | ASCII |
| `0x0004` | `GPSLongitude` | RATIONAL |
| `0x0005` | `GPSAltitudeRef` | BYTE |
| `0x0006` | `GPSAltitude` | RATIONAL |
| `0x0007` | `GPSTimeStamp` | RATIONAL |
| `0x0008` | `GPSSatellites` | ASCII |
| `0x0009` | `GPSStatus` | ASCII |
| `0x000A` | `GPSMeasureMode` | ASCII |
| `0x000B` | `GPSDOP` | RATIONAL |
| `0x000C` | `GPSSpeedRef` | ASCII |
| `0x000D` | `GPSSpeed` | RATIONAL |
| `0x000E` | `GPSTrackRef` | ASCII |
| `0x000F` | `GPSTrack` | RATIONAL |
| `0x0010` | `GPSImgDirectionRef` | ASCII |
| `0x0011` | `GPSImgDirection` | RATIONAL |
| `0x0012` | `GPSMapDatum` | ASCII |
| `0x0013` | `GPSDestLatitudeRef` | ASCII |
| `0x0014` | `GPSDestLatitude` | RATIONAL |
| `0x0015` | `GPSDestLongitudeRef` | ASCII |
| `0x0016` | `GPSDestLongitude` | RATIONAL |
| `0x0017` | `GPSDestBearingRef` | ASCII |
| `0x0018` | `GPSDestBearing` | RATIONAL |
| `0x0019` | `GPSDestDistanceRef` | ASCII |
| `0x001A` | `GPSDestDistance` | RATIONAL |
| `0x001B` | `GPSProcessingMethod` | UNDEFINED |
| `0x001C` | `GPSAreaInformation` | UNDEFINED |
| `0x001D` | `GPSDateStamp` | ASCII |
| `0x001E` | `GPSDifferential` | SHORT |
| `0x001F` | `GPSHPositioningError` | RATIONAL |

## Interoperability IFD (`interop`)

| Tag | Name | Type |
|---|---|---|
| `0x0001` | `InteroperabilityIndex` | ASCII |
| `0x0002` | `InteroperabilityVersion` | UNDEFINED |
| `0x1000` | `RelatedImageFileFormat` | ASCII |
| `0x1001` | `RelatedImageWidth` | SHORT or LONG |
| `0x1002` | `RelatedImageLength` | SHORT or LONG |
