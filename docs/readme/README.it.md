# Photo Metadata Repair

> Questo README è stato tradotto dall'inglese tramite IA. Potrebbe richiedere una revisione da parte di madrelingua. Il file `README.md` in inglese è la versione autorevole.

Ripara e sincronizza in batch i metadati di foto e video per Google Photos, Apple Photos, Finder e importazioni tra dispositivi.

Lo strumento lavora sui metadati che spesso determinano quando e dove un file appare nella libreria:

- ora di scatto
- fuso orario
- coordinate GPS
- date di creazione/modifica del filesystem
- campi temporali duplicati in EXIF, TIFF/IFD, XMP, IPTC e QuickTime
- marca e modello della fotocamera o del dispositivo

Per impostazione predefinita, i file supportati vengono copiati in una nuova cartella di output e vengono modificate solo le copie. Usa `--in-place` solo se vuoi modificare direttamente gli originali.

## Requisiti

Obbligatori:

- Bash
- Ruby
- ExifTool

Opzionale:

- strumenti JPEG XL, solo con `--convert-jpg-to-jxl`

Esempi:

```bash
brew install exiftool jpeg-xl
sudo apt install libimage-exiftool-perl libjxl-tools
sudo dnf install perl-Image-ExifTool jpegxl-tools
```

Su Windows, esegui lo script da WSL, Git Bash o MSYS2 e installa lì le dipendenze.

## Avvio rapido

Anteprima senza modifiche:

```bash
./media-metadata-repair --dry-run --tz +08:00 /path/to/photos
```

Riparazione:

```bash
./media-metadata-repair --tz +08:00 --repair-mislabelled-heic --verify-sample 20 /path/to/photos
```

Aggiungere una posizione GPS comune:

```bash
./media-metadata-repair --tz +08:00 --gps 31.2304,121.4737 /path/to/photos
```

Recuperare l'ora dal nome file quando manca:

```bash
./media-metadata-repair --from-filename-if-missing --tz +08:00 /path/to/photos
```

## Opzioni comuni

```text
--tz +08:00                 Scrive il fuso orario; richiesto per recuperare dai nomi file
--gps LAT,LON               Scrive le coordinate GPS
--set-time DATETIME         Imposta l'ora di acquisizione per tutti i file
--set-gps LAT,LON           Imposta il GPS per tutti i file
--set-make MAKE             Imposta la marca del dispositivo
--set-model MODEL           Imposta il modello del dispositivo
--metadata-csv FILE         Legge time,gps,make,model da CSV
--dry-run                   Mostra le azioni senza modificare
--output-dir DIR            Sceglie la cartella di output
--in-place                  Modifica direttamente gli input
--from-filename-if-missing  Completa l'ora mancante dal nome file
--convert-jpg-to-jxl        Converte JPEG in JPEG XL senza perdita
--replace-jpg-with-jxl      Rimuove il JPEG dopo conversione riuscita
--repair-mislabelled-heic   Ripara .heic che contengono dati JPEG
--verify-sample N           Stampa un campione di metadati dopo la riparazione
```

Estensioni supportate: `jpg`, `jpeg`, `heic`, `png`, `tif`, `tiff`, `mp4`, `mov`, `m4v`, `3gp`.

## Sicurezza

- La modalità predefinita ripara copie e lascia invariati gli originali.
- `--in-place` modifica direttamente i file di input.
- `--dry-run` mostra il piano prima della scrittura.
- `--replace-jpg-with-jxl` rimuove un JPEG solo dopo una conversione JPEG XL riuscita.
- La riparazione usa `-overwrite_original` di ExifTool sui file riparati, quindi i backup ExifTool non vengono conservati.

## Campi scritti

Priorità temporale per le immagini:

```text
EXIF:DateTimeOriginal
EXIF:CreateDate
IFD0/TIFF:ModifyDate
FileCreateDate
FileModifyDate
```

Il valore scelto viene sincronizzato in EXIF, TIFF/IFD, XMP, IPTC e nelle date del file.

Per i video, lo strumento usa i campi QuickTime per MP4, MOV, M4V e 3GP. Non è una cosa solo Apple: anche telefoni Android, droni, action cam ed esportazioni video usano spesso questi campi.

GPS viene scritto in EXIF GPS e XMP-exif GPS. Marca e modello vengono sincronizzati fra IFD0/XMP-tiff per immagini e QuickTime Keys/UserData per video.

Se un campo non temporale è in conflitto, lo strumento conserva i valori esistenti, salta la sincronizzazione automatica e mostra un avviso. I valori dati con `--set-*` o `--metadata-csv` hanno priorità.

## Verifica

```bash
./media-metadata-repair --tz +08:00 --verify-sample 20 /path/to/photos
exiftool -a -G1 -s -time:all '-OffsetTime*' -GPS:All /path/to/file
```
