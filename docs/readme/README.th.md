# Photo Metadata Repair

> README นี้แปลจากเอกสารต้นฉบับภาษาอังกฤษด้วย AI และอาจต้องให้เจ้าของภาษาตรวจทานอีกครั้ง ไฟล์ `README.md` ภาษาอังกฤษเป็นฉบับอ้างอิงหลัก

เครื่องมือนี้ใช้ซ่อมแซมและซิงค์เมตาดาต้าของรูปภาพและวิดีโอแบบเป็นชุด สำหรับ Google Photos, Apple Photos, Finder และไฟล์ที่นำเข้าข้ามอุปกรณ์แล้วเวลา หรือสถานที่ผิดเพี้ยน

เมตาดาต้าที่เครื่องมือให้ความสำคัญคือข้อมูลที่มักกำหนดว่าไฟล์จะปรากฏในคลังรูปเมื่อไรและที่ไหน:

- เวลาถ่าย
- ค่าเขตเวลา
- พิกัด GPS
- วันที่สร้าง/แก้ไขของไฟล์
- ฟิลด์เวลาซ้ำใน EXIF, TIFF/IFD, XMP, IPTC และ QuickTime
- ยี่ห้อและรุ่นของกล้องหรืออุปกรณ์

โดยค่าเริ่มต้น เครื่องมือจะคัดลอกไฟล์ที่รองรับไปยังโฟลเดอร์ผลลัพธ์ใหม่ แล้วแก้ไขเฉพาะสำเนา ใช้ `--in-place` เฉพาะเมื่อคุณต้องการแก้ไขไฟล์ต้นฉบับโดยตรง

## สิ่งที่ต้องมี

จำเป็น:

- Bash
- Ruby
- ExifTool

ไม่บังคับ:

- เครื่องมือ JPEG XL เฉพาะเมื่อใช้ `--convert-jpg-to-jxl`

ตัวอย่างการติดตั้ง:

```bash
brew install exiftool jpeg-xl
sudo apt install libimage-exiftool-perl libjxl-tools
sudo dnf install perl-Image-ExifTool jpegxl-tools
```

บน Windows แนะนำให้รันผ่าน WSL, Git Bash หรือ MSYS2 และติดตั้ง dependencies ในสภาพแวดล้อมนั้น

## เริ่มต้นอย่างรวดเร็ว

ทดลองก่อนโดยไม่แก้ไขไฟล์:

```bash
./media-metadata-repair --dry-run --tz +08:00 /path/to/photos
```

จากนั้นซ่อมแซมจริง:

```bash
./media-metadata-repair --tz +08:00 --repair-mislabelled-heic --verify-sample 20 /path/to/photos
```

เขียน GPS เดียวกันให้ทุกไฟล์:

```bash
./media-metadata-repair --tz +08:00 --gps 31.2304,121.4737 /path/to/photos
```

เติมเวลาถ่ายจากชื่อไฟล์เมื่อเมตาดาต้าฝังอยู่หายไป:

```bash
./media-metadata-repair --from-filename-if-missing --tz +08:00 /path/to/photos
```

## ตัวเลือกที่ใช้บ่อย

```text
--tz +08:00                 เขียนค่าเขตเวลา
--gps LAT,LON               เขียนพิกัด GPS
--set-time DATETIME         ตั้งเวลาถ่ายให้ทุกไฟล์
--set-gps LAT,LON           ตั้ง GPS ให้ทุกไฟล์
--set-make MAKE             ตั้งยี่ห้ออุปกรณ์
--set-model MODEL           ตั้งรุ่นอุปกรณ์
--metadata-csv FILE         ใช้ CSV ที่มี time,gps,make,model
--dry-run                   แสดงแผนโดยไม่แก้ไขไฟล์
--output-dir DIR            กำหนดโฟลเดอร์ผลลัพธ์
--in-place                  แก้ไขไฟล์ต้นฉบับโดยตรง
--from-filename-if-missing  เติมเวลาจากชื่อไฟล์เฉพาะเมื่อเวลาในไฟล์หายไป
--convert-jpg-to-jxl        แปลง JPEG เป็น JPEG XL แบบไม่สูญเสียข้อมูล
--replace-jpg-with-jxl      ลบ JPEG หลังแปลงสำเร็จ
--repair-mislabelled-heic   ซ่อม .heic ที่จริง ๆ แล้วเป็นข้อมูล JPEG
--verify-sample N           แสดงเมตาดาต้าตัวอย่างหลังซ่อม
```

รองรับนามสกุล: `jpg`, `jpeg`, `heic`, `png`, `tif`, `tiff`, `mp4`, `mov`, `m4v`, `3gp`

## ความปลอดภัย

- โหมดเริ่มต้นแก้ไขสำเนา ไม่แก้ไขต้นฉบับ
- `--in-place` จะแก้ไขไฟล์อินพุตโดยตรง
- `--dry-run` ใช้ตรวจแผนก่อนเขียนจริง
- `--replace-jpg-with-jxl` จะลบ JPEG เฉพาะหลังจากสร้าง JPEG XL สำเร็จ
- ขั้นตอนซ่อมใช้ `-overwrite_original` ของ ExifTool จึงไม่เก็บไฟล์สำรองของ ExifTool

## ฟิลด์ที่เขียน

ลำดับความสำคัญของเวลาสำหรับรูปภาพ:

```text
EXIF:DateTimeOriginal
EXIF:CreateDate
IFD0/TIFF:ModifyDate
FileCreateDate
FileModifyDate
```

เวลาที่เลือกจะถูกซิงค์ไปยัง EXIF, TIFF/IFD, XMP, IPTC และวันที่สร้าง/แก้ไขของไฟล์

สำหรับวิดีโอ เครื่องมือใช้ฟิลด์ตระกูล QuickTime สำหรับ MP4, MOV, M4V และ 3GP ซึ่งไม่ได้จำกัดเฉพาะ Apple เพราะโทรศัพท์ Android, โดรน, กล้องแอ็กชัน และโปรแกรมตัดต่อจำนวนมากก็ใช้ฟิลด์เหล่านี้

GPS จะเขียนลง EXIF GPS และ XMP-exif GPS ส่วนยี่ห้อ/รุ่นจะซิงค์ระหว่าง IFD0/XMP-tiff สำหรับรูป และ QuickTime Keys/UserData สำหรับวิดีโอ

ถ้าฟิลด์ที่ไม่ใช่เวลาเกิดความขัดแย้ง เครื่องมือจะเก็บค่าที่มีอยู่ ข้ามการซิงค์อัตโนมัติ และแสดงคำเตือน ค่าที่กำหนดด้วย `--set-*` หรือ `--metadata-csv` มีความสำคัญสูงสุด

## ตรวจสอบ

```bash
./media-metadata-repair --tz +08:00 --verify-sample 20 /path/to/photos
exiftool -a -G1 -s -time:all '-OffsetTime*' -GPS:All /path/to/file
```

