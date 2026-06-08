# Photo Metadata Repair

Batch repair and synchronize photo/video metadata for Google Photos, Apple Photos, Finder, and cross-device imports.

批量修复和同步照片/视频元数据，适用于 Google Photos、Apple Photos、Finder 以及跨设备导入场景。

## Translated READMEs

The English README is the source version. The following localized READMEs were translated by AI and may need review by native speakers:

- [中文（简体）](docs/readme/README.zh-CN.md)
- [中文（繁體）](docs/readme/README.zh-TW.md)
- [廣東話](docs/readme/README.yue.md)
- [Français](docs/readme/README.fr.md)
- [Italiano](docs/readme/README.it.md)
- [日本語](docs/readme/README.ja.md)
- [한국어](docs/readme/README.ko.md)
- [ไทย](docs/readme/README.th.md)
- [Tiếng Việt](docs/readme/README.vi.md)
- [Nederlands](docs/readme/README.nl.md)
- [Español](docs/readme/README.es.md)

This tool focuses on the metadata that usually decides when and where a media file appears in photo libraries:

- Capture time
- Timezone offset
- GPS coordinates
- Filesystem create/modify dates
- Duplicate time fields across EXIF, TIFF/IFD, XMP, IPTC, and QuickTime
- Camera/device make and model fields across supported metadata families

The metadata repair path does not rename files, change extensions, or re-encode image/video data.

By default, the tool writes repaired copies into a new output directory in the current working directory. Use `--in-place` only when you want to modify the input files directly.

JPEG to JPEG XL conversion is optional and explicit. When enabled, it writes `.jxl` files next to the repaired JPEG copies and keeps the JPEG files.

## Requirements

Required:

- Bash
- Ruby
- ExifTool

Optional:

- JPEG XL tools, only when using `--convert-jpg-to-jxl`

Install `exiftool` first. On macOS, Linux, or Windows, use your normal package manager or the official ExifTool package for your platform.

Examples:

```bash
# macOS with Homebrew
brew install exiftool

# Debian/Ubuntu
sudo apt install libimage-exiftool-perl

# Fedora
sudo dnf install perl-Image-ExifTool
```

For optional JPEG XL conversion, install the JPEG XL tools so `cjxl` is on your `PATH`.

Examples:

```bash
# macOS with Homebrew
brew install jpeg-xl

# Debian/Ubuntu, package name varies by release
sudo apt install libjxl-tools

# Fedora
sudo dnf install jpegxl-tools
```

On Windows, run the script from WSL, Git Bash, MSYS2, or another Bash environment, and install Bash, Ruby, ExifTool, and optional JPEG XL tools there.

## Safety Model

- Default mode copies supported media into a repaired-output directory, then edits those copies.
- `--in-place` edits the input files directly.
- `--dry-run` prints the copy plan and the later metadata commands without modifying files.
- `--replace-jpg-with-jxl` deletes JPEG files only after successful JPEG XL conversion. In default mode it deletes repaired JPEG copies; with `--in-place` it deletes original JPEG files.
- The repair step uses ExifTool's `-overwrite_original` on the files being repaired, so ExifTool backup files are not kept.

## Quick Start

Recommended workflow for an unfamiliar library:

```bash
./media-metadata-repair --dry-run --tz +08:00 /path/to/photos
```

```bash
./media-metadata-repair \
  --tz +08:00 \
  --repair-mislabelled-heic \
  --verify-sample 20 \
  /path/to/photos
```

Use `--dry-run` first, inspect the planned output directory and commands, then run without `--dry-run`. Add options only for the metadata you actually want to write:

- Add `--gps LAT,LON` when all files should get the same location.
- Add `--from-filename-if-missing` when embedded capture times are missing and filenames contain reliable timestamps.
- Add `--metadata-csv FILE` when different files need different manual metadata.
- Add `--in-place` only when you intentionally want to modify originals.

Modify the input files directly instead of writing repaired copies:

```bash
./media-metadata-repair \
  --in-place \
  --tz +08:00 \
  /path/to/photos
```

Repair timestamps and write GPS coordinates:

```bash
./media-metadata-repair \
  --tz +08:00 \
  --gps 31.011525,121.237075 \
  --repair-mislabelled-heic \
  --verify-sample 20 \
  /path/to/photos
```

## CLI Options

```text
Usage:
  media-metadata-repair [options] <folder-or-file>...

Options:
  --tz +08:00                 Timezone offset to write into EXIF/XMP offset tags. Required for filename recovery.
  --gps LAT,LON               Write GPS coordinates to EXIF and XMP GPS fields.
  --set-time DATETIME         Set capture time for all inputs, then sync supported time fields.
  --set-gps LAT,LON           Set GPS coordinates for all inputs.
  --set-make MAKE             Set camera/device make for all inputs.
  --set-model MODEL           Set camera/device model for all inputs.
  --metadata-csv FILE         Set per-file metadata from CSV columns: file,time,gps,make,model.
  --dry-run                   Print actions without modifying files.
  --output-dir DIR            Write repaired copies under DIR. Default: ./media-metadata-repair-output-YYYYMMDD-HHMMSS
  --in-place                  Modify input files directly instead of working on repaired copies.
  --from-filename-if-missing  Fill missing embedded capture time from supported filename timestamps.
  --yes                       Skip interactive confirmation for filename-derived timestamps.
  --convert-jpg-to-jxl        Losslessly transcode .jpg/.jpeg files to .jxl files.
  --overwrite-jxl             Overwrite existing .jxl files when converting JPEG to JPEG XL.
  --replace-jpg-with-jxl      After successful JPEG XL conversion, remove the corresponding .jpg/.jpeg file.
  --repair-mislabelled-heic   Repair .heic files that contain JPEG data without renaming them.
  --verify-sample N           Print metadata for N random files after repair.
```

Supported extensions:

```text
jpg, jpeg, heic, png, tif, tiff, mp4, mov, m4v, 3gp
```

## Common Scenarios

Fix files that Google Photos sorts by upload/download time:

```bash
./media-metadata-repair --tz +08:00 --verify-sample 20 /path/to/photos
```

Fill missing capture time from filenames such as `IMG_20190811_105900.jpg`:

```bash
./media-metadata-repair --from-filename-if-missing --tz +08:00 /path/to/photos
```

Repair `.heic` files that are actually JPEG bytes:

```bash
./media-metadata-repair --repair-mislabelled-heic --tz +08:00 /path/to/photos
```

Keep originals untouched while producing JPEG XL copies:

```bash
./media-metadata-repair --convert-jpg-to-jxl --tz +08:00 /path/to/photos
```

## What Gets Written

For images, the tool first chooses one capture-time source, then synchronizes that value everywhere else. Priority:

```text
EXIF:DateTimeOriginal
EXIF:CreateDate
IFD0/TIFF:ModifyDate
FileCreateDate
FileModifyDate
```

That means files with only TIFF/IFD time, such as `IFD0:ModifyDate`, can still be repaired.

The chosen image time is synchronized to:

```text
EXIF:DateTimeOriginal
EXIF:CreateDate
IFD0:ModifyDate
XMP:DateCreated
XMP:CreateDate
XMP-photoshop:DateCreated
IPTC:DateCreated
IPTC:TimeCreated
FileCreateDate
FileModifyDate
```

For timezone, it writes:

```text
OffsetTime
OffsetTimeOriginal
OffsetTimeDigitized
```

For GPS, it writes:

```text
GPSLatitude
GPSLongitude
GPSLatitudeRef
GPSLongitudeRef
XMP-exif:GPSLatitude
XMP-exif:GPSLongitude
```

For videos, the tool uses QuickTime-family metadata because MP4, MOV, M4V, and 3GP are ISO Base Media / QuickTime-style containers. This is not Apple-only: Android phones, drones, action cameras, and many editing/export tools also store video creation dates in fields that ExifTool exposes under the `QuickTime` family.

Video time priority:

```text
QuickTime:CreateDate
QuickTime:MediaCreateDate
QuickTime:TrackCreateDate
FileCreateDate
FileModifyDate
```

Then it synchronizes:

```text
QuickTime:CreateDate
QuickTime:MediaCreateDate
QuickTime:TrackCreateDate
FileCreateDate
FileModifyDate
```

For camera/device identity, the tool reads existing make/model values and writes them across supported fields:

```text
Images: IFD0:Make, IFD0:Model, XMP-tiff:Make, XMP-tiff:Model
Videos: Keys:Make, Keys:Model, UserData:Make, UserData:Model
```

If multiple make/model fields already disagree, the tool keeps the existing values, skips automatic sync for the conflicting field, and warns you.

## Conflict Policy

Time conflicts are resolved by the fallback order. For example, if `EXIF:DateTimeOriginal` and `IFD0:ModifyDate` disagree, the tool uses the higher-priority time source and synchronizes file create/modify dates from it.

For non-time metadata such as GPS and camera/device make/model, the tool is conservative:

- If only one supported field has a value, the tool copies it to missing counterpart fields.
- If counterpart fields already agree, the tool may normalize/sync them.
- If counterpart fields conflict, the tool does not modify that field.
- Conflicts are printed as prominent terminal warnings using bold white text on a red background.

Example:

```text
CONFLICT: GPS differs in IMG_0042.jpg; keeping existing values and skipping automatic sync.
```

This warning means the tool preserved the existing conflicting values for that field. It does not mean the whole run failed.

Manual input has the highest priority. If you pass `--set-time`, `--set-gps`, `--set-make`, `--set-model`, or `--metadata-csv`, those user-provided values are treated as intentional and are written to the supported fields.

## Manual Metadata Input

Use `--set-time`, `--set-gps`, `--set-make`, and `--set-model` when you want to explicitly apply information to all input files:

```bash
./media-metadata-repair \
  --set-time "2019-08-11 10:59:00" \
  --set-gps "31.2304,121.4737" \
  --set-make "Apple" \
  --set-model "iPhone 11" \
  /path/to/photos
```

Accepted time examples:

```text
2019:08:11 10:59:00
2019-08-11 10:59:00
20190811105900
```

For images, manual time is written to EXIF/TIFF/XMP/IPTC and file create/modify dates. Manual GPS is written to EXIF GPS and XMP-exif GPS. Manual make/model is written to IFD0 and XMP-tiff.

For videos, manual time is written to QuickTime `CreateDate`, `MediaCreateDate`, `TrackCreateDate`, and file create/modify dates. Manual GPS is written to QuickTime `Keys:GPSCoordinates` and `UserData:GPSCoordinates`. Manual make/model is written to QuickTime Keys and UserData.

For per-file batch edits, use `--metadata-csv`:

```csv
file,time,gps,make,model
IMG_001.jpg,2019-08-11 10:59:00,"31.2304,121.4737",Apple,iPhone 11
DCIM/IMG_002.jpg,2019:08:12 09:30:00,,Sony,ILCE-7M3
Videos/clip.mp4,2020-01-02 03:04:05,"35.6895,139.6917",Sony,ILCE-7M3
```

Then run:

```bash
./media-metadata-repair \
  --metadata-csv metadata.csv \
  /path/to/photos
```

The `file` column may be a filename, relative path, or absolute path. In default output-directory mode, CSV entries are matched against the repaired copies by relative path first, then unique filename. If two files share the same basename, use a relative path such as `DCIM/IMG_002.jpg` so the match is unambiguous.

## JPEG XL Conversion

Use `--convert-jpg-to-jxl` to create lossless JPEG XL files after metadata repair:

```bash
./media-metadata-repair \
  --tz +08:00 \
  --convert-jpg-to-jxl \
  /path/to/photos
```

The script uses `cjxl --lossless_jpeg=1`, which losslessly transcodes JPEG files into JPEG XL without recompressing pixels. Output files use the standard `.jxl` extension:

```text
/path/to/photos/IMG_0001.jpg -> ./media-metadata-repair-output-YYYYMMDD-HHMMSS/photos/IMG_0001.jxl
```

After a successful conversion, the `.jxl` file's filesystem create and modify dates are synchronized from the repaired JPEG.

By default, repaired files go under a new `./media-metadata-repair-output-YYYYMMDD-HHMMSS` directory from the current working directory, preserving the input directory structure. Original input files are kept unchanged. Existing `.jxl` files in the repaired output are skipped.

Choose another repaired-output directory:

```bash
./media-metadata-repair \
  --convert-jpg-to-jxl \
  --output-dir /path/to/repaired-output \
  /path/to/photos
```

Overwrite existing `.jxl` outputs:

```bash
./media-metadata-repair \
  --convert-jpg-to-jxl \
  --overwrite-jxl \
  /path/to/photos
```

Replace repaired JPEG files with JPEG XL files:

```bash
./media-metadata-repair \
  --convert-jpg-to-jxl \
  --replace-jpg-with-jxl \
  /path/to/photos
```

With the default output-directory mode, this removes only the repaired JPEG copies in the output directory. Originals remain unchanged. If you combine it with `--in-place`, the original `.jpg/.jpeg` files are removed after their `.jxl` files are successfully created.

If you pass individual JPEG files instead of a directory, outputs go directly under the output directory:

```text
/path/to/IMG_0001.jpg -> ./media-metadata-repair-output-YYYYMMDD-HHMMSS/IMG_0001.jxl
```

## Filename Time Recovery

Use `--from-filename-if-missing` when EXIF/TIFF/QuickTime capture times are missing but the filename contains a reliable timestamp:

```bash
./media-metadata-repair \
  --from-filename-if-missing \
  --tz +08:00 \
  --verify-sample 20 \
  /path/to/photos
```

Before writing anything, the tool scans the target files and groups all matched filenames by naming rule. If all files use the same rule, it shows one random sample. If multiple rules are found, it shows one random sample per rule:

```text
Filename timestamp preflight:
  Proposed writes: 42
  Rules found: 2

- YYYYMMDDHHMMSS (compact 14-digit timestamp): 30 file(s)
  sample: IMG_20190811105900.jpg -> 2019:08:11 10:59:00
- YYYYMMDD_HHMMSS (8-digit date plus 6-digit time): 12 file(s)
  sample: VID_20190811_110322.mp4 -> 2019:08:11 11:03:22
- Unix Time (milliseconds) (13-digit Unix time in milliseconds): 6 file(s)
  sample: download_1581822285796.jpg -> 2020:02:16 11:04:45
```

Type `yes` to continue. Use `--dry-run` to preview without writing, or `--yes` for a non-interactive run after you have already verified the naming rules.

Supported filename timestamp rules are intentionally conservative:

```text
YYYYMMDDHHMMSS
YYYYMMDD_HHMMSS
YYYY-MM-DD_HH-MM-SS
Unix Time (seconds)
Unix Time (milliseconds)
```

Unix Time matching is prefix-independent: any standalone 10-digit or 13-digit number in the filename can match if it converts to a valid date in the configured timezone.

Examples that work:

```text
20190811105900.jpg -> 2019:08:11 10:59:00
IMG_20190811_105900.heic -> 2019:08:11 10:59:00
Screenshot 2019-08-11 10.59.00.png -> 2019:08:11 10:59:00
download_1581822285796.jpg -> 2020:02:16 11:04:45
1581822285.jpg -> 2020:02:16 11:04:45
```

Ambiguous or date-only names such as `09May26.jpg` are not written automatically. They need a manual rule because the filename alone does not prove whether it means `2009-05-26`, `2026-05-09`, or another convention.

## Why This Helps Google Photos

Google Photos tends to prefer embedded capture metadata when it exists and looks consistent. If embedded time fields are missing or contradictory, it may fall back to upload time, download time, or filesystem timestamps.

This tool reduces that ambiguity by making the common time fields agree:

- EXIF capture time for images
- QuickTime creation time for videos
- existing EXIF/XMP timezone offsets when present, or an explicit `--tz` when requested
- Finder file dates aligned with the embedded capture time

## EXIF, TIFF, and JFIF

`EXIF` is camera/photo metadata commonly stored inside JPEG, TIFF, HEIC, and some RAW-derived files. It contains capture-oriented fields such as `DateTimeOriginal`, `CreateDate`, GPS, make/model, lens data, and exposure settings.

`TIFF` is both an image format and a tag structure. In JPEG/EXIF files, many baseline tags live in TIFF-style IFDs, especially `IFD0`. Fields like `IFD0:Make`, `IFD0:Model`, and `IFD0:ModifyDate` are often described as TIFF/IFD metadata even when the file itself is a JPEG.

`JFIF` is the JPEG File Interchange Format header. It describes how JPEG image data is packaged, including things like density/resolution units and thumbnail hints. JFIF is not a rich capture metadata system, so it usually does not contain the real shooting time, camera model, GPS, or timezone. If you meant `JIFF`, that is usually a typo for `JFIF`.

## Mislabelled HEIC Files

Some files have a `.heic` extension but contain JPEG data. `exiftool` reports these as:

```text
Not a valid HEIC (looks more like a JPEG)
```

Use:

```bash
./media-metadata-repair --repair-mislabelled-heic /path/to/photos
```

The tool writes metadata through a temporary JPEG copy, then moves it back to the original path. The filename and extension stay unchanged.

## Verification

Check one file:

```bash
exiftool -a -G1 -s -time:all '-OffsetTime*' -GPS:All \
  -XMP-exif:GPSLatitude -XMP-exif:GPSLongitude \
  /path/to/file
```

Use built-in sampling:

```bash
./media-metadata-repair \
  --tz +08:00 \
  --verify-sample 20 \
  /path/to/photos
```

A healthy image usually has:

```text
DateTimeOriginal: 2020:07:06 17:23:52
CreateDate: 2020:07:06 17:23:52
ModifyDate: 2020:07:06 17:23:52
OffsetTimeOriginal: +08:00
FileModifyDate: 2020:07:06 17:23:52+08:00
```

A healthy video usually has:

```text
QuickTime:CreateDate: 2020:07:06 09:23:52
FileModifyDate: 2020:07:06 17:23:52+08:00
```

The QuickTime value is often stored as UTC while Finder shows local time.

## Safety Notes

- Run `--dry-run` before large batches.
- By default, originals are not modified; repaired copies are written under a new output directory.
- Use `--in-place` only after you are comfortable modifying the original files directly.
- The repair step uses ExifTool's `-overwrite_original` on the files it is repairing, so ExifTool backup files are not kept in the output directory.
- Metadata repair does not change pixels, video streams, filenames, or extensions.
- JPEG XL conversion is opt-in; it writes new `.jxl` files next to repaired JPEG copies and does not delete original JPEG files.
- Finder creation dates are not reliable after download/copy operations; embedded media metadata is usually a better source.
- PNG metadata support varies across apps, so Google Photos may behave less consistently with PNG than with JPEG/HEIC.

## Installing as a Command

Optional: symlink the script into a directory on your `PATH`:

```bash
ln -s "$PWD/media-metadata-repair" /usr/local/bin/media-metadata-repair
```

Then run:

```bash
media-metadata-repair --tz +08:00 --verify-sample 20 /path/to/photos
```

## Codex Skill

This folder also includes `SKILL.md`, so it can be used as a Codex skill. The skill tells Codex when to use the tool, which fields to prioritize, and how to verify results after a batch repair.
