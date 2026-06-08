# Photo Metadata Repair

> Este README fue traducido por IA desde la documentación original en inglés. Puede requerir revisión por hablantes nativos. El `README.md` en inglés es la versión de referencia.

Repara y sincroniza por lotes metadatos de fotos y videos para Google Photos, Apple Photos, Finder e importaciones entre dispositivos.

La herramienta se centra en los metadatos que suelen determinar cuándo y dónde aparece un archivo en una biblioteca de fotos:

- hora de captura
- zona horaria
- coordenadas GPS
- fechas de creación/modificación del sistema de archivos
- campos de tiempo duplicados en EXIF, TIFF/IFD, XMP, IPTC y QuickTime
- marca y modelo de la cámara o dispositivo

Por defecto, copia los archivos compatibles a un nuevo directorio de salida y modifica esas copias. Usa `--in-place` solo si quieres modificar los originales directamente.

## Requisitos

Obligatorios:

- Bash
- Ruby
- ExifTool

Opcional:

- herramientas JPEG XL, solo con `--convert-jpg-to-jxl`

Ejemplos:

```bash
brew install exiftool jpeg-xl
sudo apt install libimage-exiftool-perl libjxl-tools
sudo dnf install perl-Image-ExifTool jpegxl-tools
```

En Windows, ejecuta el script desde WSL, Git Bash o MSYS2 e instala allí las dependencias.

## Inicio rápido

Primero, simula la ejecución:

```bash
./media-metadata-repair --dry-run --tz +08:00 /path/to/photos
```

Después repara:

```bash
./media-metadata-repair --tz +08:00 --repair-mislabelled-heic --verify-sample 20 /path/to/photos
```

Escribir un GPS común:

```bash
./media-metadata-repair --tz +08:00 --gps 31.2304,121.4737 /path/to/photos
```

Rellenar la hora desde el nombre del archivo cuando falta:

```bash
./media-metadata-repair --from-filename-if-missing --tz +08:00 /path/to/photos
```

## Opciones comunes

```text
--tz +08:00                 Escribir la zona horaria; obligatorio al recuperar desde nombres de archivo
--gps LAT,LON               Escribir coordenadas GPS
--set-time DATETIME         Definir hora de captura para todos los archivos
--set-gps LAT,LON           Definir GPS para todos los archivos
--set-make MAKE             Definir marca del dispositivo
--set-model MODEL           Definir modelo del dispositivo
--metadata-csv FILE         Aplicar time,gps,make,model desde CSV
--dry-run                   Mostrar acciones sin modificar archivos
--output-dir DIR            Elegir directorio de salida
--in-place                  Modificar directamente los archivos de entrada
--from-filename-if-missing  Completar desde el nombre solo si falta la hora embebida
--convert-jpg-to-jxl        Convertir JPEG a JPEG XL sin pérdida
--replace-jpg-with-jxl      Eliminar JPEG tras conversión exitosa
--repair-mislabelled-heic   Reparar .heic que en realidad contienen datos JPEG
--verify-sample N           Mostrar metadatos de muestra después de reparar
```

Extensiones compatibles: `jpg`, `jpeg`, `heic`, `png`, `tif`, `tiff`, `mp4`, `mov`, `m4v`, `3gp`.

## Seguridad

- El modo predeterminado repara copias y deja intactos los originales.
- `--in-place` modifica directamente los archivos de entrada.
- `--dry-run` permite revisar el plan antes de escribir.
- `--replace-jpg-with-jxl` elimina un JPEG solo después de una conversión JPEG XL exitosa.
- La reparación usa `-overwrite_original` de ExifTool, por lo que no se conservan copias de respaldo de ExifTool.

## Campos escritos

Prioridad de tiempo para imágenes:

```text
EXIF:DateTimeOriginal
EXIF:CreateDate
IFD0/TIFF:ModifyDate
FileCreateDate
FileModifyDate
```

La hora elegida se sincroniza con EXIF, TIFF/IFD, XMP, IPTC y las fechas del archivo.

Para videos, la herramienta usa campos de la familia QuickTime en MP4, MOV, M4V y 3GP. No es algo exclusivo de Apple: teléfonos Android, drones, cámaras de acción y editores de video también suelen usar esos campos.

GPS se escribe en EXIF GPS y XMP-exif GPS. Marca/modelo se sincroniza entre IFD0/XMP-tiff para imágenes y QuickTime Keys/UserData para videos.

Si hay conflicto en un campo que no es de tiempo, la herramienta conserva los valores existentes, omite la sincronización automática y muestra una advertencia clara. Los valores de `--set-*` o `--metadata-csv` tienen máxima prioridad.

## Verificación

```bash
./media-metadata-repair --tz +08:00 --verify-sample 20 /path/to/photos
exiftool -a -G1 -s -time:all '-OffsetTime*' -GPS:All /path/to/file
```
