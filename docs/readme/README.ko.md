# Photo Metadata Repair

> 이 README는 영어 원문을 AI로 번역한 문서입니다. 원어민 검토가 필요할 수 있습니다. 기준 문서는 영어 `README.md`입니다.

Google Photos, Apple Photos, Finder, 여러 기기 간 가져오기 과정에서 어긋난 사진/동영상 메타데이터를 일괄 복구하고 동기화합니다.

이 도구는 미디어 라이브러리에서 파일이 언제, 어디에 표시되는지를 좌우하는 메타데이터를 다룹니다.

- 촬영 시간
- 시간대 오프셋
- GPS 좌표
- 파일 시스템 생성/수정 날짜
- EXIF, TIFF/IFD, XMP, IPTC, QuickTime의 중복 시간 필드
- 카메라/기기 제조사와 모델

기본 모드에서는 지원되는 미디어를 새 출력 디렉터리로 복사한 뒤 복사본을 수정합니다. 원본을 직접 수정하려는 경우에만 `--in-place`를 사용하세요.

## 요구 사항

필수:

- Bash
- Ruby
- ExifTool

선택:

- JPEG XL 도구. `--convert-jpg-to-jxl` 사용 시에만 필요

설치 예:

```bash
brew install exiftool jpeg-xl
sudo apt install libimage-exiftool-perl libjxl-tools
sudo dnf install perl-Image-ExifTool jpegxl-tools
```

Windows에서는 WSL, Git Bash, MSYS2 같은 Bash 환경에서 실행하고 해당 환경에 의존성을 설치하세요.

## 빠른 시작

먼저 미리보기:

```bash
./media-metadata-repair --dry-run --tz +08:00 /path/to/photos
```

수정 실행:

```bash
./media-metadata-repair --tz +08:00 --repair-mislabelled-heic --verify-sample 20 /path/to/photos
```

공통 GPS 쓰기:

```bash
./media-metadata-repair --tz +08:00 --gps 31.2304,121.4737 /path/to/photos
```

파일명에서 누락된 촬영 시간 채우기:

```bash
./media-metadata-repair --from-filename-if-missing --tz +08:00 /path/to/photos
```

## 주요 옵션

```text
--tz +08:00                 시간대 오프셋 쓰기
--gps LAT,LON               GPS 좌표 쓰기
--set-time DATETIME         모든 입력에 촬영 시간 설정
--set-gps LAT,LON           모든 입력에 GPS 설정
--set-make MAKE             기기 제조사 설정
--set-model MODEL           기기 모델 설정
--metadata-csv FILE         CSV에서 time,gps,make,model 적용
--dry-run                   파일을 수정하지 않고 작업만 출력
--output-dir DIR            출력 디렉터리 지정
--in-place                  입력 파일 직접 수정
--from-filename-if-missing  내장 시간이 없을 때만 파일명에서 보완
--convert-jpg-to-jxl        JPEG를 JPEG XL로 무손실 변환
--replace-jpg-with-jxl      변환 성공 후 JPEG 삭제
--repair-mislabelled-heic   실제 내용이 JPEG인 .heic 파일 수정
--verify-sample N           수정 후 N개 메타데이터 출력
```

지원 확장자: `jpg`, `jpeg`, `heic`, `png`, `tif`, `tiff`, `mp4`, `mov`, `m4v`, `3gp`.

## 안전 모델

- 기본 모드는 복사본을 수정하고 원본은 변경하지 않습니다.
- `--in-place`는 입력 파일을 직접 수정합니다.
- `--dry-run`으로 복사 계획과 명령을 사전에 확인할 수 있습니다.
- `--replace-jpg-with-jxl`은 JPEG XL 변환 성공 후에만 JPEG를 삭제합니다.
- 수정 단계는 ExifTool의 `-overwrite_original`을 사용하므로 ExifTool 백업 파일은 남지 않습니다.

## 기록되는 필드

이미지 시간 우선순위:

```text
EXIF:DateTimeOriginal
EXIF:CreateDate
IFD0/TIFF:ModifyDate
FileCreateDate
FileModifyDate
```

선택된 시간은 EXIF, TIFF/IFD, XMP, IPTC, 파일 생성/수정 날짜로 동기화됩니다.

동영상은 MP4, MOV, M4V, 3GP에 QuickTime 계열 필드를 사용합니다. 이는 Apple 전용이 아니며 Android 휴대폰, 드론, 액션 카메라, 편집 프로그램 출력에서도 흔히 쓰입니다.

GPS는 EXIF GPS와 XMP-exif GPS에 기록됩니다. 제조사/모델은 이미지의 IFD0/XMP-tiff와 동영상의 QuickTime Keys/UserData 사이에서 동기화됩니다.

시간이 아닌 필드에 충돌이 있으면 기존 값을 보존하고 자동 동기화를 건너뛰며 경고를 표시합니다. `--set-*` 또는 `--metadata-csv`로 제공한 수동 값이 가장 높은 우선순위를 가집니다.

## 검증

```bash
./media-metadata-repair --tz +08:00 --verify-sample 20 /path/to/photos
exiftool -a -G1 -s -time:all '-OffsetTime*' -GPS:All /path/to/file
```

