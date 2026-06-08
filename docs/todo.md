# TODO: Metadata Repair Follow-ups

## Fixed in this pass

- Support prefix-independent Unix filename timestamps.
  - Match standalone 10-digit Unix seconds as `Unix Time (seconds)`.
  - Match standalone 13-digit Unix milliseconds as `Unix Time (milliseconds)`.
  - Keep existing conservative calendar rules: `YYYYMMDDHHMMSS`, `YYYYMMDD_HHMMSS`, and `YYYY-MM-DD_HH-MM-SS`.
- Preserve repaired JPEG filesystem dates when converting to JPEG XL.
  - After `cjxl`, sync the `.jxl` file's create/modify dates from the repaired `.jpg`.
- Repair the already-generated batch output.
  - Existing `.jxl` files in `/Users/x/Downloads/photo-metadata-repair-output-batch-copy` now have corrected `FileCreateDate` and `FileModifyDate`.
  - Existing `.mp4` files in that output directory now have filesystem dates synchronized from QuickTime `CreateDate`.
- Account for QuickTime UTC handling.
  - MP4 date reads/writes must use `-api QuickTimeUTC=1` to avoid an 8-hour offset on local `+08:00` timestamps.
- Avoid Bash heredoc hangs.
  - Ruby helper logic now lives in `scripts/*.rb` files and is invoked directly from `media-metadata-repair`.

## Issues found

- The first ad-hoc batch flow repaired JPG/JXL but only copied MP4 files, so MP4 filesystem dates stayed at download time.
- Some MP4 files had GPS and some did not. All 9 MP4 files had embedded QuickTime creation times.
- Large inline Bash heredocs feeding Ruby can hang in this environment while Bash writes the heredoc pipe.
  - Status: fixed by extracting Ruby helpers into real files.

## Verification checklist

- `bash -n media-metadata-repair`
- Confirm Unix timestamp parsing examples:
  - `download_1581822285796` -> `Unix Time (milliseconds)` -> `2020:02:16 11:04:45`
  - `IMG-1581822285` -> `Unix Time (seconds)` -> `2020:02:16 11:04:45`
- Confirm `.jxl` filesystem dates match repaired `.jpg` dates.
- Confirm `.mp4` filesystem dates match QuickTime `CreateDate` with `QuickTimeUTC=1`.
