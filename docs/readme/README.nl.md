# Photo Metadata Repair

> Deze README is door AI vertaald vanuit de Engelstalige brondocumentatie. Controle door moedertaalsprekers kan nodig zijn. De Engelse `README.md` is leidend.

Herstelt en synchroniseert foto- en videometadata in batches voor Google Photos, Apple Photos, Finder en imports tussen apparaten.

De tool richt zich op metadata die meestal bepaalt wanneer en waar een mediabestand in een fotobibliotheek verschijnt:

- opnametijd
- tijdzone-offset
- GPS-coordinaten
- aanmaak- en wijzigingsdatums van het bestandssysteem
- dubbele tijdvelden in EXIF, TIFF/IFD, XMP, IPTC en QuickTime
- merk en model van camera of apparaat

Standaard kopieert de tool ondersteunde media naar een nieuwe uitvoermap en past alleen die kopieen aan. Gebruik `--in-place` alleen als je de originele bestanden direct wilt wijzigen.

## Vereisten

Verplicht:

- Bash
- Ruby
- ExifTool

Optioneel:

- JPEG XL-tools, alleen nodig met `--convert-jpg-to-jxl`

Voorbeelden:

```bash
brew install exiftool jpeg-xl
sudo apt install libimage-exiftool-perl libjxl-tools
sudo dnf install perl-Image-ExifTool jpegxl-tools
```

Op Windows: voer het script uit via WSL, Git Bash of MSYS2 en installeer de afhankelijkheden in die omgeving.

## Snel starten

Eerst controleren zonder te wijzigen:

```bash
./media-metadata-repair --dry-run --tz +08:00 /path/to/photos
```

Daarna herstellen:

```bash
./media-metadata-repair --tz +08:00 --repair-mislabelled-heic --verify-sample 20 /path/to/photos
```

Een gezamenlijke GPS-locatie schrijven:

```bash
./media-metadata-repair --tz +08:00 --gps 31.2304,121.4737 /path/to/photos
```

Ontbrekende opnametijd uit bestandsnamen halen:

```bash
./media-metadata-repair --from-filename-if-missing --tz +08:00 /path/to/photos
```

## Veelgebruikte opties

```text
--tz +08:00                 Tijdzone-offset schrijven; vereist voor herstel vanuit bestandsnamen
--gps LAT,LON               GPS-coordinaten schrijven
--set-time DATETIME         Opnametijd instellen voor alle input
--set-gps LAT,LON           GPS instellen voor alle input
--set-make MAKE             Apparaatmerk instellen
--set-model MODEL           Apparaatmodel instellen
--metadata-csv FILE         time,gps,make,model toepassen vanuit CSV
--dry-run                   Acties tonen zonder bestanden te wijzigen
--output-dir DIR            Uitvoermap kiezen
--in-place                  Inputbestanden direct wijzigen
--from-filename-if-missing  Alleen ontbrekende ingebedde tijd uit bestandsnaam aanvullen
--convert-jpg-to-jxl        JPEG verliesloos naar JPEG XL converteren
--replace-jpg-with-jxl      JPEG verwijderen na succesvolle conversie
--repair-mislabelled-heic   .heic-bestanden herstellen die eigenlijk JPEG-data bevatten
--verify-sample N           Na herstel metadata van N bestanden tonen
```

Ondersteunde extensies: `jpg`, `jpeg`, `heic`, `png`, `tif`, `tiff`, `mp4`, `mov`, `m4v`, `3gp`.

## Veiligheid

- Standaard worden kopieen hersteld en blijven originelen ongemoeid.
- `--in-place` wijzigt inputbestanden direct.
- `--dry-run` toont het plan voordat er geschreven wordt.
- `--replace-jpg-with-jxl` verwijdert een JPEG alleen na succesvolle JPEG XL-conversie.
- De herstelstap gebruikt ExifTool `-overwrite_original`; ExifTool-back-ups blijven dus niet bewaard.

## Geschreven velden

Tijdprioriteit voor afbeeldingen:

```text
EXIF:DateTimeOriginal
EXIF:CreateDate
IFD0/TIFF:ModifyDate
FileCreateDate
FileModifyDate
```

De gekozen tijd wordt gesynchroniseerd naar EXIF, TIFF/IFD, XMP, IPTC en bestandsdatums.

Voor video gebruikt de tool QuickTime-velden voor MP4, MOV, M4V en 3GP. Dat is niet alleen Apple-specifiek; Android-telefoons, drones, actioncams en videobewerkers gebruiken deze velden ook vaak.

GPS wordt geschreven naar EXIF GPS en XMP-exif GPS. Merk/model wordt gesynchroniseerd tussen IFD0/XMP-tiff voor afbeeldingen en QuickTime Keys/UserData voor video.

Bij conflicten in niet-tijdvelden behoudt de tool bestaande waarden, slaat automatische synchronisatie over en toont een duidelijke waarschuwing. Waarden uit `--set-*` of `--metadata-csv` hebben hoogste prioriteit.

## Controleren

```bash
./media-metadata-repair --tz +08:00 --verify-sample 20 /path/to/photos
exiftool -a -G1 -s -time:all '-OffsetTime*' -GPS:All /path/to/file
```
