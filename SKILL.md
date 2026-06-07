---
name: photo-metadata-repair
description: Repair and synchronize photo/video metadata in batches, including capture time, timezone offsets, GPS coordinates, EXIF, TIFF/IFD, XMP, IPTC, QuickTime, and filesystem dates. Use when the user wants media metadata fixed for Google Photos, Apple Photos, Finder, or cross-device consistency.
metadata:
  short-description: Batch repair media metadata
---

# Photo Metadata Repair

Use this skill when a user wants to repair, normalize, or batch-edit metadata for photos and videos.

Core tool:

```bash
./media-metadata-repair
```

## Workflow

1. Install required dependencies if needed: Bash, Ruby, and ExifTool. Use the platform's package manager or official package.

```bash
# macOS with Homebrew
brew install exiftool

# Debian/Ubuntu
sudo apt install libimage-exiftool-perl
```

Install JPEG XL tools only when JPEG XL conversion is requested:

```bash
# macOS with Homebrew
brew install jpeg-xl

# Debian/Ubuntu, package name varies by release
sudo apt install libjxl-tools
```

On Windows, run the script from WSL, Git Bash, or MSYS2, and install Bash, Ruby, ExifTool, and optional JPEG XL tools in that environment.

2. Run a dry pass when the target set is large or unfamiliar:

```bash
./media-metadata-repair --dry-run --tz +08:00 /path/to/photos
```

Dry-run should preview the repaired-copy output paths used by a real default-mode run. Treat paths printed under the output directory as the files that would later receive ExifTool writes.

3. Repair timestamps and offsets. By default, this writes repaired copies to a new `./media-metadata-repair-output-YYYYMMDD-HHMMSS` directory and leaves originals unchanged:

```bash
./media-metadata-repair --tz +08:00 --repair-mislabelled-heic --verify-sample 20 /path/to/photos
```

4. Repair timestamps and write GPS coordinates:

```bash
./media-metadata-repair --tz +08:00 --gps 31.011525,121.237075 --verify-sample 20 /path/to/photos
```

5. Recover missing embedded capture time from filenames only after a grouped sample preflight:

```bash
./media-metadata-repair --from-filename-if-missing --tz +08:00 --verify-sample 20 /path/to/photos
```

6. Optionally create lossless JPEG XL files for JPEG files:

```bash
./media-metadata-repair --tz +08:00 --convert-jpg-to-jxl /path/to/photos
```

Use `--replace-jpg-with-jxl` only when the user wants the JPEG files removed after successful JPEG XL creation. In default output-directory mode this removes repaired JPEG copies only; with `--in-place` it removes original JPEG files.

## Field Policy

For images, choose one capture-time source in this order:

1. `EXIF:DateTimeOriginal`
2. `EXIF:CreateDate`
3. `IFD0/TIFF:ModifyDate`
4. `FileCreateDate`
5. `FileModifyDate`

Then synchronize it to:

- `EXIF:DateTimeOriginal`
- `EXIF:CreateDate`
- `IFD0:ModifyDate`
- `XMP:DateCreated`
- `XMP:CreateDate`
- `XMP-photoshop:DateCreated`
- `IPTC:DateCreated`
- `IPTC:TimeCreated`
- `FileCreateDate`
- `FileModifyDate`

For timezone, write:

- `OffsetTime`
- `OffsetTimeOriginal`
- `OffsetTimeDigitized`

For GPS, write:

- `GPSLatitude`
- `GPSLongitude`
- `GPSLatitudeRef`
- `GPSLongitudeRef`
- `XMP-exif:GPSLatitude`
- `XMP-exif:GPSLongitude`

For videos, use QuickTime-family metadata as the main source for MP4/MOV/M4V/3GP. This is not Apple-only; Android phones, drones, and many cameras/editors also store MP4-family creation times in fields ExifTool exposes as QuickTime tags. Choose video time in this order:

- `QuickTime:CreateDate`
- `QuickTime:MediaCreateDate`
- `QuickTime:TrackCreateDate`
- `FileCreateDate`
- `FileModifyDate`

Then synchronize `QuickTime:CreateDate`, `QuickTime:MediaCreateDate`, `QuickTime:TrackCreateDate`, `FileCreateDate`, and `FileModifyDate`.

For camera/device identity, merge existing make/model values across supported fields:

- Images: `IFD0:Make`, `IFD0:Model`, `XMP-tiff:Make`, `XMP-tiff:Model`
- Videos: `Keys:Make`, `Keys:Model`, `UserData:Make`, `UserData:Model`

If make/model fields conflict, skip automatic sync for the conflicting field and warn the user.

Conflict policy:

- Time conflicts are resolved by the fallback order, and file create/modify dates follow the selected time.
- Non-time fields such as GPS and make/model should sync only when missing or already consistent.
- If non-time counterpart fields conflict, preserve the existing values, skip automatic sync for that field, and print a prominent terminal warning with bold white text on a red background.
- Manual inputs from `--set-*` or `--metadata-csv` are explicit user intent and may overwrite existing values.

Manual metadata input has the highest priority. Use:

- `--set-time DATETIME` for one time applied to all inputs
- `--set-gps LAT,LON` for one coordinate applied to all inputs
- `--set-make MAKE` and `--set-model MODEL` for one device identity applied to all inputs
- `--metadata-csv FILE` for per-file values using columns such as `file,time,gps,make,model`

Accepted time formats include `YYYY:MM:DD HH:MM:SS`, `YYYY-MM-DD HH:MM:SS`, and `YYYYMMDDHHMMSS`. In default output-directory mode, CSV file keys should match repaired copies by relative path or unique basename.

By default, copy supported media to a fresh repaired-output directory before writing metadata. Use `--output-dir DIR` to choose that directory. Multiple input directories with the same basename are placed under distinct output roots to avoid overwriting same-named files. Use `--in-place` only when the user explicitly wants to modify originals.

When `--convert-jpg-to-jxl` is used, run metadata repair first, then create `.jxl` files next to the repaired `.jpg/.jpeg` copies using `cjxl --lossless_jpeg=1`. Keep JPEG files unless `--replace-jpg-with-jxl` is explicitly supplied. Skip existing `.jxl` files unless `--overwrite-jxl` is explicitly supplied. The standard output extension is `.jxl`.

When `--from-filename-if-missing` is used, only fill files that have no embedded image capture time (`DateTimeOriginal`, `CreateDate`, `ModifyDate`) or no embedded video QuickTime time (`CreateDate`, `MediaCreateDate`, `TrackCreateDate`). Before writing, scan the target set, group matched filenames by rule, and show one random sample per rule. Continue only after the user confirms the sample mapping, unless `--yes` was explicitly supplied.

Supported automatic filename rules are conservative and require a concrete time:

- `YYYYMMDDHHMMSS`, such as `20190811105900`
- `YYYYMMDD_HHMMSS`, such as `IMG_20190811_105900`
- `YYYY-MM-DD_HH-MM-SS`, including separator variants such as `2019-08-11 10.59.00`

Do not automatically write ambiguous or date-only names such as `09May26`; report them as unsupported/ambiguous unless the user asks for a manual rule.

## Guardrails

- Do not rename files or change extensions unless the user explicitly asks.
- Do not re-encode pixels or video streams.
- Default behavior repairs copies in an output directory. Do not use `--in-place` unless the user explicitly asks to modify originals.
- JPEG XL conversion is opt-in and creates `.jxl` files next to repaired JPEG copies. Delete JPEG files only when `--replace-jpg-with-jxl` is explicitly requested; this deletes originals only when combined with `--in-place`.
- For `.heic` files that contain JPEG bytes, use `--repair-mislabelled-heic`; it writes via a temporary JPEG file and restores the original path.
- Treat Finder creation time as unreliable after downloads or copies. Prefer embedded capture metadata.
- For Google Photos, ensure EXIF/XMP/QuickTime time fields agree before upload.
- Do not let filename-derived time overwrite existing embedded capture time unless the user explicitly asks for a separate force mode.
- Treat JFIF as JPEG packaging metadata, not as a reliable capture metadata source.

## Verification

Use this command for spot checks:

```bash
exiftool -a -G1 -s -time:all '-OffsetTime*' -GPS:All -XMP-exif:GPSLatitude -XMP-exif:GPSLongitude /path/to/file
```
