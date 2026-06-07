# Photo Metadata Repair

> 呢份 README 由 AI 根據英文原文翻譯，可能需要母語使用者再覆核。英文 `README.md` 係準確版本。

批量修復同同步相片、影片 metadata，啱用喺 Google Photos、Apple Photos、Finder，同埋唔同裝置匯入之後時間或者位置亂咗嘅情況。

呢個工具主要處理會影響相簿排序同定位嘅資料：

- 拍攝時間
- 時區偏移
- GPS 座標
- 檔案建立/修改日期
- EXIF、TIFF/IFD、XMP、IPTC、QuickTime 入面重複嘅時間欄位
- 相機或者裝置品牌、型號

預設會先複製支援嘅媒體去新輸出資料夾，之後修復副本。除非你真係想直接改原檔，先好用 `--in-place`。

## 需要安裝

必需：

- Bash
- Ruby
- ExifTool

可選：

- JPEG XL 工具，只係用 `--convert-jpg-to-jxl` 先需要

安裝例子：

```bash
brew install exiftool jpeg-xl
sudo apt install libimage-exiftool-perl libjxl-tools
sudo dnf install perl-Image-ExifTool jpegxl-tools
```

Windows 建議用 WSL、Git Bash 或 MSYS2 跑，並喺嗰個環境安裝依賴。

## 快速開始

先 dry run：

```bash
./media-metadata-repair --dry-run --tz +08:00 /path/to/photos
```

確認之後正式修復：

```bash
./media-metadata-repair --tz +08:00 --repair-mislabelled-heic --verify-sample 20 /path/to/photos
```

寫入同一個 GPS：

```bash
./media-metadata-repair --tz +08:00 --gps 31.2304,121.4737 /path/to/photos
```

如果檔名有可靠時間，可以補返缺失嘅拍攝時間：

```bash
./media-metadata-repair --from-filename-if-missing --tz +08:00 /path/to/photos
```

## 常用選項

```text
--tz +08:00                 寫入時區偏移
--gps LAT,LON               寫入 GPS
--set-time DATETIME         幫所有輸入設定拍攝時間
--set-gps LAT,LON           幫所有輸入設定 GPS
--set-make MAKE             設定裝置品牌
--set-model MODEL           設定裝置型號
--metadata-csv FILE         用 CSV 按檔案寫入 time,gps,make,model
--dry-run                   只顯示計劃，唔改檔
--output-dir DIR            指定輸出資料夾
--in-place                  直接改輸入檔
--from-filename-if-missing  只喺嵌入時間缺失時由檔名補時間
--convert-jpg-to-jxl        無損轉 JPEG 去 JPEG XL
--replace-jpg-with-jxl      轉換成功後刪走相應 JPEG
--repair-mislabelled-heic   修復副檔名係 .heic 但內容其實係 JPEG 嘅檔
--verify-sample N           修復後抽樣睇 metadata
```

支援：`jpg`、`jpeg`、`heic`、`png`、`tif`、`tiff`、`mp4`、`mov`、`m4v`、`3gp`。

## 安全模式

- 預設改副本，唔改原檔。
- `--in-place` 會直接改輸入檔。
- `--dry-run` 可以寫入前睇清楚會做乜。
- `--replace-jpg-with-jxl` 只會喺 JPEG XL 成功建立之後刪 JPEG；預設模式只刪輸出資料夾入面嘅副本，配合 `--in-place` 先會刪原檔。
- 修復時用 ExifTool `-overwrite_original`，唔會保留 ExifTool 備份檔。

## 寫入欄位

相片時間優先順序：

```text
EXIF:DateTimeOriginal
EXIF:CreateDate
IFD0/TIFF:ModifyDate
FileCreateDate
FileModifyDate
```

之後同步去 EXIF、TIFF/IFD、XMP、IPTC 同檔案建立/修改日期。

影片用 QuickTime 系列欄位，適用於 MP4、MOV、M4V、3GP，亦常見於 Android 手機、航拍機、運動相機同剪片軟件輸出檔。

如果 GPS、品牌、型號等非時間欄位有衝突，工具會保留原有值、跳過自動同步，並顯示明顯警告。`--set-*` 同 `--metadata-csv` 係手動指定，優先級最高。

## 驗證

```bash
./media-metadata-repair --tz +08:00 --verify-sample 20 /path/to/photos
exiftool -a -G1 -s -time:all '-OffsetTime*' -GPS:All /path/to/file
```

