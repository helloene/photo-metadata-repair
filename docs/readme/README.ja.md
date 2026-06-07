# Photo Metadata Repair

> この README は英語の原文から AI により翻訳されました。ネイティブ話者による確認が必要な場合があります。正式な内容は英語の `README.md` です。

Google Photos、Apple Photos、Finder、複数デバイス間の取り込みでずれた写真・動画メタデータを一括で修復、同期します。

このツールは、メディアライブラリでの表示日時や場所に影響しやすいメタデータを扱います。

- 撮影日時
- タイムゾーンオフセット
- GPS 座標
- ファイルシステムの作成日/変更日
- EXIF、TIFF/IFD、XMP、IPTC、QuickTime の重複した日時フィールド
- カメラ/デバイスのメーカーとモデル

デフォルトでは、対応メディアを新しい出力ディレクトリへコピーし、そのコピーを修復します。元ファイルを直接変更したい場合だけ `--in-place` を使ってください。

## 必要なもの

必須：

- Bash
- Ruby
- ExifTool

任意：

- JPEG XL ツール。`--convert-jpg-to-jxl` 使用時のみ必要

インストール例：

```bash
brew install exiftool jpeg-xl
sudo apt install libimage-exiftool-perl libjxl-tools
sudo dnf install perl-Image-ExifTool jpegxl-tools
```

Windows では WSL、Git Bash、MSYS2 などの Bash 環境で実行し、その環境に依存関係を入れてください。

## クイックスタート

まず確認：

```bash
./media-metadata-repair --dry-run --tz +08:00 /path/to/photos
```

修復を実行：

```bash
./media-metadata-repair --tz +08:00 --repair-mislabelled-heic --verify-sample 20 /path/to/photos
```

共通 GPS を書き込む：

```bash
./media-metadata-repair --tz +08:00 --gps 31.2304,121.4737 /path/to/photos
```

ファイル名から欠落した撮影日時を補う：

```bash
./media-metadata-repair --from-filename-if-missing --tz +08:00 /path/to/photos
```

## 主なオプション

```text
--tz +08:00                 タイムゾーンオフセットを書き込む
--gps LAT,LON               GPS 座標を書き込む
--set-time DATETIME         すべての入力に撮影日時を設定
--set-gps LAT,LON           すべての入力に GPS を設定
--set-make MAKE             デバイスのメーカーを設定
--set-model MODEL           デバイスのモデルを設定
--metadata-csv FILE         CSV から time,gps,make,model を適用
--dry-run                   変更せず処理内容だけ表示
--output-dir DIR            出力ディレクトリを指定
--in-place                  入力ファイルを直接変更
--from-filename-if-missing  埋め込み日時がない場合のみファイル名から補完
--convert-jpg-to-jxl        JPEG を JPEG XL へロスレス変換
--replace-jpg-with-jxl      変換成功後に対応する JPEG を削除
--repair-mislabelled-heic   実体が JPEG の .heic ファイルを修復
--verify-sample N           修復後に N 件のメタデータを表示
```

対応拡張子：`jpg`、`jpeg`、`heic`、`png`、`tif`、`tiff`、`mp4`、`mov`、`m4v`、`3gp`。

## 安全性

- デフォルトではコピーを修復し、元ファイルは変更しません。
- `--in-place` は入力ファイルを直接変更します。
- `--dry-run` でコピー計画とコマンドを事前確認できます。
- `--replace-jpg-with-jxl` は JPEG XL 変換成功後にだけ JPEG を削除します。
- 修復には ExifTool の `-overwrite_original` を使うため、ExifTool のバックアップファイルは残りません。

## 書き込まれるフィールド

画像日時の優先順位：

```text
EXIF:DateTimeOriginal
EXIF:CreateDate
IFD0/TIFF:ModifyDate
FileCreateDate
FileModifyDate
```

選ばれた日時は EXIF、TIFF/IFD、XMP、IPTC、ファイル作成/変更日に同期されます。

動画では MP4、MOV、M4V、3GP に対して QuickTime 系フィールドを使います。これは Apple 限定ではなく、Android スマートフォン、ドローン、アクションカメラ、編集ソフトの書き出しでもよく使われます。

GPS は EXIF GPS と XMP-exif GPS に書き込まれます。メーカー/モデルは画像では IFD0/XMP-tiff、動画では QuickTime Keys/UserData に同期されます。

時間以外のフィールドに競合がある場合、既存値を保持し、自動同期をスキップして警告を表示します。`--set-*` や `--metadata-csv` の手動指定が最優先です。

## 検証

```bash
./media-metadata-repair --tz +08:00 --verify-sample 20 /path/to/photos
exiftool -a -G1 -s -time:all '-OffsetTime*' -GPS:All /path/to/file
```

