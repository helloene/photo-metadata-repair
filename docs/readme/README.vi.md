# Photo Metadata Repair

> README này được AI dịch từ tài liệu gốc tiếng Anh và có thể cần người bản ngữ rà soát. File `README.md` tiếng Anh là bản có thẩm quyền.

Công cụ sửa và đồng bộ hàng loạt metadata của ảnh/video cho Google Photos, Apple Photos, Finder và các lần nhập dữ liệu giữa nhiều thiết bị.

Công cụ tập trung vào các metadata thường quyết định thời gian và vị trí hiển thị của tệp trong thư viện ảnh:

- thời gian chụp
- độ lệch múi giờ
- tọa độ GPS
- ngày tạo/sửa của hệ thống tệp
- các trường thời gian trùng lặp trong EXIF, TIFF/IFD, XMP, IPTC và QuickTime
- hãng và model của máy ảnh/thiết bị

Mặc định, công cụ sao chép các tệp được hỗ trợ vào một thư mục đầu ra mới rồi sửa bản sao. Chỉ dùng `--in-place` khi bạn thật sự muốn sửa trực tiếp tệp gốc.

## Yêu cầu

Bắt buộc:

- Bash
- Ruby
- ExifTool

Tùy chọn:

- công cụ JPEG XL, chỉ cần khi dùng `--convert-jpg-to-jxl`

Ví dụ cài đặt:

```bash
brew install exiftool jpeg-xl
sudo apt install libimage-exiftool-perl libjxl-tools
sudo dnf install perl-Image-ExifTool jpegxl-tools
```

Trên Windows, hãy chạy trong WSL, Git Bash hoặc MSYS2 và cài dependencies trong môi trường đó.

## Bắt đầu nhanh

Chạy thử trước:

```bash
./media-metadata-repair --dry-run --tz +08:00 /path/to/photos
```

Sau đó sửa:

```bash
./media-metadata-repair --tz +08:00 --repair-mislabelled-heic --verify-sample 20 /path/to/photos
```

Ghi cùng một GPS:

```bash
./media-metadata-repair --tz +08:00 --gps 31.2304,121.4737 /path/to/photos
```

Lấy thời gian từ tên tệp khi metadata thời gian bị thiếu:

```bash
./media-metadata-repair --from-filename-if-missing --tz +08:00 /path/to/photos
```

## Tùy chọn thường dùng

```text
--tz +08:00                 Ghi độ lệch múi giờ; bắt buộc khi khôi phục từ tên tệp
--gps LAT,LON               Ghi tọa độ GPS
--set-time DATETIME         Đặt thời gian chụp cho mọi đầu vào
--set-gps LAT,LON           Đặt GPS cho mọi đầu vào
--set-make MAKE             Đặt hãng thiết bị
--set-model MODEL           Đặt model thiết bị
--metadata-csv FILE         Áp dụng time,gps,make,model từ CSV
--dry-run                   Chỉ in kế hoạch, không sửa tệp
--output-dir DIR            Chọn thư mục đầu ra
--in-place                  Sửa trực tiếp tệp đầu vào
--from-filename-if-missing  Chỉ điền từ tên tệp khi thiếu thời gian nhúng
--convert-jpg-to-jxl        Chuyển JPEG sang JPEG XL không mất dữ liệu
--replace-jpg-with-jxl      Xóa JPEG sau khi chuyển đổi thành công
--repair-mislabelled-heic   Sửa .heic thực chất chứa dữ liệu JPEG
--verify-sample N           In metadata mẫu sau khi sửa
```

Hỗ trợ phần mở rộng: `jpg`, `jpeg`, `heic`, `png`, `tif`, `tiff`, `mp4`, `mov`, `m4v`, `3gp`.

## An toàn

- Mặc định sửa bản sao, không thay đổi bản gốc.
- `--in-place` sửa trực tiếp tệp đầu vào.
- `--dry-run` giúp xem kế hoạch trước khi ghi.
- `--replace-jpg-with-jxl` chỉ xóa JPEG sau khi tạo JPEG XL thành công.
- Bước sửa dùng `-overwrite_original` của ExifTool nên không giữ file sao lưu ExifTool.

## Trường được ghi

Thứ tự ưu tiên thời gian cho ảnh:

```text
EXIF:DateTimeOriginal
EXIF:CreateDate
IFD0/TIFF:ModifyDate
FileCreateDate
FileModifyDate
```

Thời gian được chọn sẽ được đồng bộ vào EXIF, TIFF/IFD, XMP, IPTC và ngày tạo/sửa của tệp.

Với video, công cụ dùng các trường họ QuickTime cho MP4, MOV, M4V và 3GP. Đây không chỉ là định dạng Apple; điện thoại Android, drone, action camera và phần mềm dựng video cũng thường dùng các trường này.

GPS được ghi vào EXIF GPS và XMP-exif GPS. Hãng/model được đồng bộ giữa IFD0/XMP-tiff cho ảnh và QuickTime Keys/UserData cho video.

Nếu trường không phải thời gian có xung đột, công cụ giữ giá trị hiện có, bỏ qua đồng bộ tự động và hiển thị cảnh báo. Giá trị từ `--set-*` hoặc `--metadata-csv` có ưu tiên cao nhất.

## Kiểm tra

```bash
./media-metadata-repair --tz +08:00 --verify-sample 20 /path/to/photos
exiftool -a -G1 -s -time:all '-OffsetTime*' -GPS:All /path/to/file
```
