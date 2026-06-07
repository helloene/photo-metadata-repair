# Photo Metadata Repair

> Ce README a été traduit par IA depuis la documentation source en anglais. Une relecture par des locuteurs natifs peut être nécessaire. Le fichier `README.md` anglais fait autorité.

Répare et synchronise par lots les métadonnées de photos et vidéos pour Google Photos, Apple Photos, Finder et les imports entre appareils.

L'outil cible les métadonnées qui déterminent souvent la date et le lieu d'apparition d'un fichier dans une photothèque :

- date de prise de vue
- décalage horaire
- coordonnées GPS
- dates de création/modification du système de fichiers
- champs temporels dupliqués dans EXIF, TIFF/IFD, XMP, IPTC et QuickTime
- marque et modèle de l'appareil

Par défaut, les fichiers pris en charge sont copiés dans un nouveau dossier de sortie, puis les copies sont modifiées. Utilisez `--in-place` uniquement si vous voulez modifier les originaux.

## Prérequis

Obligatoires :

- Bash
- Ruby
- ExifTool

Facultatif :

- outils JPEG XL, uniquement avec `--convert-jpg-to-jxl`

Exemples :

```bash
brew install exiftool jpeg-xl
sudo apt install libimage-exiftool-perl libjxl-tools
sudo dnf install perl-Image-ExifTool jpegxl-tools
```

Sous Windows, exécutez le script depuis WSL, Git Bash ou MSYS2, avec les dépendances installées dans cet environnement.

## Démarrage rapide

Prévisualiser sans modification :

```bash
./media-metadata-repair --dry-run --tz +08:00 /path/to/photos
```

Puis réparer :

```bash
./media-metadata-repair --tz +08:00 --repair-mislabelled-heic --verify-sample 20 /path/to/photos
```

Ajouter une position GPS commune :

```bash
./media-metadata-repair --tz +08:00 --gps 31.2304,121.4737 /path/to/photos
```

Récupérer l'heure depuis les noms de fichiers quand elle manque :

```bash
./media-metadata-repair --from-filename-if-missing --tz +08:00 /path/to/photos
```

## Options courantes

```text
--tz +08:00                 Écrire le décalage horaire
--gps LAT,LON               Écrire les coordonnées GPS
--set-time DATETIME         Définir l'heure de capture pour tous les fichiers
--set-gps LAT,LON           Définir le GPS pour tous les fichiers
--set-make MAKE             Définir la marque de l'appareil
--set-model MODEL           Définir le modèle de l'appareil
--metadata-csv FILE         Lire time,gps,make,model depuis un CSV
--dry-run                   Afficher les actions sans modifier
--output-dir DIR            Choisir le dossier de sortie
--in-place                  Modifier directement les fichiers d'entrée
--from-filename-if-missing  Compléter l'heure manquante depuis le nom
--convert-jpg-to-jxl        Convertir les JPEG en JPEG XL sans perte
--replace-jpg-with-jxl      Supprimer le JPEG après conversion réussie
--repair-mislabelled-heic   Réparer les .heic contenant en réalité du JPEG
--verify-sample N           Afficher un échantillon de métadonnées après réparation
```

Extensions prises en charge : `jpg`, `jpeg`, `heic`, `png`, `tif`, `tiff`, `mp4`, `mov`, `m4v`, `3gp`.

## Sécurité

- Le mode par défaut répare des copies et garde les originaux inchangés.
- `--in-place` modifie directement les fichiers d'entrée.
- `--dry-run` permet de vérifier le plan de copie et les commandes.
- `--replace-jpg-with-jxl` supprime un JPEG seulement après une conversion JPEG XL réussie.
- La réparation utilise `-overwrite_original` d'ExifTool sur les fichiers réparés, donc les sauvegardes ExifTool ne sont pas conservées.

## Champs écrits

Priorité des dates pour les images :

```text
EXIF:DateTimeOriginal
EXIF:CreateDate
IFD0/TIFF:ModifyDate
FileCreateDate
FileModifyDate
```

La date choisie est synchronisée vers EXIF, TIFF/IFD, XMP, IPTC et les dates de fichier.

Pour les vidéos, l'outil utilise les champs QuickTime pour MP4, MOV, M4V et 3GP. Ce n'est pas propre à Apple : les téléphones Android, drones, caméras d'action et exports vidéo utilisent aussi souvent ces champs.

Les champs GPS sont écrits dans EXIF GPS et XMP-exif GPS. La marque et le modèle sont synchronisés entre IFD0/XMP-tiff pour les images et QuickTime Keys/UserData pour les vidéos.

En cas de conflit sur un champ non temporel, l'outil conserve les valeurs existantes, ignore la synchronisation automatique et affiche un avertissement visible. Les valeurs fournies avec `--set-*` ou `--metadata-csv` ont la priorité.

## Vérification

```bash
./media-metadata-repair --tz +08:00 --verify-sample 20 /path/to/photos
exiftool -a -G1 -s -time:all '-OffsetTime*' -GPS:All /path/to/file
```

