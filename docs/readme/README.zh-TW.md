# Photo Metadata Repair

> 本 README 由 AI 從英文原始文件翻譯而來，可能需要母語使用者複核。英文 `README.md` 是權威版本。

批次修復並同步照片與影片中繼資料，適用於 Google Photos、Apple Photos、Finder，以及跨裝置匯入後時間或位置混亂的情況。

工具主要處理會影響媒體庫排序與定位的資料：

- 拍攝時間
- 時區偏移
- GPS 座標
- 檔案系統建立/修改日期
- EXIF、TIFF/IFD、XMP、IPTC、QuickTime 中重複的時間欄位
- 相機或裝置的品牌與型號欄位

預設模式會把支援的媒體複製到新的輸出目錄，再修復副本。只有明確想直接修改原始檔時，才使用 `--in-place`。

## 需求

必需：

- Bash
- Ruby
- ExifTool

可選：

- JPEG XL 工具，僅在使用 `--convert-jpg-to-jxl` 時需要

安裝範例：

```bash
brew install exiftool jpeg-xl
sudo apt install libimage-exiftool-perl libjxl-tools
sudo dnf install perl-Image-ExifTool jpegxl-tools
```

Windows 使用者建議在 WSL、Git Bash 或 MSYS2 中執行，並在該環境安裝依賴。

## 快速開始

先預演：

```bash
./media-metadata-repair --dry-run --tz +08:00 /path/to/photos
```

確認後執行：

```bash
./media-metadata-repair --tz +08:00 --repair-mislabelled-heic --verify-sample 20 /path/to/photos
```

寫入統一 GPS：

```bash
./media-metadata-repair --tz +08:00 --gps 31.2304,121.4737 /path/to/photos
```

從檔名補齊缺少的拍攝時間：

```bash
./media-metadata-repair --from-filename-if-missing --tz +08:00 /path/to/photos
```

## 常用選項

```text
--tz +08:00                 寫入時區偏移；從檔名恢復時間時必填
--gps LAT,LON               寫入 GPS 座標
--set-time DATETIME         為所有輸入設定拍攝時間
--set-gps LAT,LON           為所有輸入設定 GPS
--set-make MAKE             設定裝置品牌
--set-model MODEL           設定裝置型號
--metadata-csv FILE         從 CSV 依檔案寫入 time,gps,make,model
--dry-run                   只列印計畫，不修改檔案
--output-dir DIR            指定修復副本輸出目錄
--in-place                  直接修改輸入檔案
--from-filename-if-missing  僅在嵌入時間缺失時從檔名補齊
--convert-jpg-to-jxl        將 JPEG 無損轉為 JPEG XL
--replace-jpg-with-jxl      轉換成功後刪除對應 JPEG
--repair-mislabelled-heic   修復副檔名為 .heic 但內容為 JPEG 的檔案
--verify-sample N           修復後抽樣列印中繼資料
```

支援副檔名：`jpg`、`jpeg`、`heic`、`png`、`tif`、`tiff`、`mp4`、`mov`、`m4v`、`3gp`。

## 安全模型

- 預設修復副本，不修改原件。
- `--in-place` 會直接修改輸入檔。
- `--dry-run` 可在寫入前查看複製計畫與中繼資料命令。
- `--replace-jpg-with-jxl` 只會在 JPEG XL 轉換成功後刪除 JPEG；預設模式刪除輸出目錄中的修復副本，配合 `--in-place` 才會刪除原始 JPEG。
- 修復步驟使用 ExifTool 的 `-overwrite_original`，不保留 ExifTool 備份檔。

## 寫入哪些欄位

圖片時間優先順序：

```text
EXIF:DateTimeOriginal
EXIF:CreateDate
IFD0/TIFF:ModifyDate
FileCreateDate
FileModifyDate
```

之後同步到 EXIF、TIFF/IFD、XMP、IPTC 與檔案建立/修改日期。

影片使用 QuickTime 系列欄位，適用於 MP4、MOV、M4V、3GP，也常見於 Android 手機、無人機、運動相機和剪輯軟體匯出的檔案。

GPS 會寫入 EXIF GPS 與 XMP-exif GPS。裝置品牌/型號會在圖片 IFD0/XMP-tiff 和影片 QuickTime Keys/UserData 欄位之間同步。

如果非時間欄位已有衝突，工具會保留現有值、跳過自動同步，並列印醒目的衝突警告。`--set-*` 或 `--metadata-csv` 提供的手動值優先級最高。

## 驗證

```bash
./media-metadata-repair --tz +08:00 --verify-sample 20 /path/to/photos
exiftool -a -G1 -s -time:all '-OffsetTime*' -GPS:All /path/to/file
```
