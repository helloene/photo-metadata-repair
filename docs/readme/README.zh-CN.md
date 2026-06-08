# Photo Metadata Repair

> 本 README 由 AI 从英文源文档翻译而来，可能需要母语使用者复核。英文 `README.md` 是权威版本。

批量修复并同步照片和视频元数据，适用于 Google Photos、Apple Photos、Finder，以及跨设备导入后的时间和地点混乱问题。

工具主要处理会影响媒体库排序和定位的元数据：

- 拍摄时间
- 时区偏移
- GPS 坐标
- 文件系统创建/修改日期
- EXIF、TIFF/IFD、XMP、IPTC、QuickTime 中的重复时间字段
- 相机或设备的品牌与型号字段

默认模式会把支持的媒体复制到新的输出目录，再修复这些副本。只有在你明确想直接修改原始文件时，才使用 `--in-place`。

## 依赖

必需：

- Bash
- Ruby
- ExifTool

可选：

- JPEG XL 工具，仅在使用 `--convert-jpg-to-jxl` 时需要

示例安装：

```bash
brew install exiftool jpeg-xl
sudo apt install libimage-exiftool-perl libjxl-tools
sudo dnf install perl-Image-ExifTool jpegxl-tools
```

Windows 用户建议在 WSL、Git Bash 或 MSYS2 中运行，并在该环境里安装依赖。

## 快速开始

先预演：

```bash
./media-metadata-repair --dry-run --tz +08:00 /path/to/photos
```

确认无误后运行：

```bash
./media-metadata-repair --tz +08:00 --repair-mislabelled-heic --verify-sample 20 /path/to/photos
```

写入统一 GPS：

```bash
./media-metadata-repair --tz +08:00 --gps 31.2304,121.4737 /path/to/photos
```

从文件名补齐缺失拍摄时间：

```bash
./media-metadata-repair --from-filename-if-missing --tz +08:00 /path/to/photos
```

## 常用选项

```text
--tz +08:00                 写入时区偏移；从文件名恢复时间时必填
--gps LAT,LON               写入 GPS 坐标
--set-time DATETIME         为所有输入设置拍摄时间
--set-gps LAT,LON           为所有输入设置 GPS
--set-make MAKE             设置设备品牌
--set-model MODEL           设置设备型号
--metadata-csv FILE         从 CSV 按文件写入 time,gps,make,model
--dry-run                   只打印计划，不修改文件
--output-dir DIR            指定修复副本输出目录
--in-place                  直接修改输入文件
--from-filename-if-missing  仅在嵌入时间缺失时从文件名补齐
--convert-jpg-to-jxl        将 JPEG 无损转为 JPEG XL
--replace-jpg-with-jxl      转换成功后删除对应 JPEG
--repair-mislabelled-heic   修复扩展名为 .heic 但内容为 JPEG 的文件
--verify-sample N           修复后抽样打印元数据
```

支持扩展名：`jpg`、`jpeg`、`heic`、`png`、`tif`、`tiff`、`mp4`、`mov`、`m4v`、`3gp`。

## 安全模型

- 默认修复副本，不改原件。
- `--in-place` 会直接修改输入文件。
- `--dry-run` 可在写入前查看复制计划和元数据命令。
- `--replace-jpg-with-jxl` 只会在 JPEG XL 转换成功后删除 JPEG；默认模式删除的是输出目录里的修复副本，配合 `--in-place` 才会删除原始 JPEG。
- 修复步骤使用 ExifTool 的 `-overwrite_original`，不会保留 ExifTool 备份文件。

## 写入哪些字段

图片时间优先级：

```text
EXIF:DateTimeOriginal
EXIF:CreateDate
IFD0/TIFF:ModifyDate
FileCreateDate
FileModifyDate
```

随后同步到 EXIF、TIFF/IFD、XMP、IPTC 和文件创建/修改日期。

视频使用 QuickTime 系列字段，适用于 MP4、MOV、M4V、3GP，也常见于 Android 手机、无人机、运动相机和剪辑软件导出文件。

GPS 会写入 EXIF GPS 与 XMP-exif GPS 字段。设备品牌/型号会在图片的 IFD0/XMP-tiff 字段和视频的 QuickTime Keys/UserData 字段之间同步。

如果非时间字段已有冲突，工具会保留现有值、跳过自动同步，并打印醒目的冲突警告。通过 `--set-*` 或 `--metadata-csv` 提供的手动值优先级最高。

## 验证

抽样验证：

```bash
./media-metadata-repair --tz +08:00 --verify-sample 20 /path/to/photos
```

检查单个文件：

```bash
exiftool -a -G1 -s -time:all '-OffsetTime*' -GPS:All /path/to/file
```
