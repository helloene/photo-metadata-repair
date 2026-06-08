#!/usr/bin/env ruby
require "csv"
require "find"
require "shellwords"

dry_run, tz, global_time, global_gps, global_make, global_model, metadata_csv, *paths = ARGV
dry_run = dry_run == "1"
image_exts = %w[.jpg .jpeg .heic .png .tif .tiff]
video_exts = %w[.mp4 .mov .m4v .3gp]
media_exts = image_exts + video_exts

def media_file?(path, media_exts)
  File.file?(path) && media_exts.include?(File.extname(path).downcase)
end

def collect_targets(paths, media_exts)
  paths.flat_map do |path|
    expanded = File.expand_path(path)
    if File.directory?(expanded)
      found = []
      Find.find(expanded) { |item| found << item if media_file?(item, media_exts) }
      found
    elsif media_file?(expanded, media_exts)
      [expanded]
    else
      []
    end
  end.uniq
end

def normalize_time(value)
  return nil if value.nil? || value.strip.empty?
  text = value.strip
  return "#{$1}:#{$2}:#{$3} #{$4}:#{$5}:#{$6}" if text =~ /\A(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})\z/
  return "#{$1}:#{$2}:#{$3} #{$4}:#{$5}:#{$6}" if text =~ /\A(\d{4})[-:](\d{2})[-:](\d{2})[ T_](\d{2}):?(\d{2}):?(\d{2})/
  text
end

def iptc_date(datetime)
  datetime[0, 10].delete(":")
end

def iptc_time(datetime)
  datetime[11, 8]
end

def parse_gps(value, lat_value = nil, lon_value = nil)
  if value && !value.strip.empty?
    parts = value.strip.split(/\s*,\s*/)
    return [parts[0], parts[1]] if parts.length >= 2 && !parts[0].empty? && !parts[1].empty?
  end
  return [lat_value.strip, lon_value.strip] if lat_value && lon_value && !lat_value.strip.empty? && !lon_value.strip.empty?
  nil
end

def row_value(row, *names)
  names.each do |name|
    value = row[name]
    return value if value && !value.strip.empty?
  end
  nil
end

def resolve_target(key, targets)
  return nil if key.nil? || key.strip.empty?
  normalized = key.strip.tr("\\", "/")
  expanded = File.expand_path(normalized)
  exact = targets.select { |target| target == expanded || target.tr("\\", "/") == normalized }
  return exact.first if exact.length == 1
  suffix_matches = targets.select { |target| target.tr("\\", "/").end_with?("/#{normalized}") }
  return suffix_matches.first if suffix_matches.length == 1
  basename_matches = targets.select { |target| File.basename(target) == File.basename(normalized) }
  return basename_matches.first if basename_matches.length == 1
  warn "Could not uniquely match CSV file '#{key}'"
  nil
end

def metadata_args_for(file, metadata, image_exts, video_exts, tz)
  ext = File.extname(file).downcase
  datetime = normalize_time(metadata[:time])
  gps = parse_gps(metadata[:gps], metadata[:lat], metadata[:lon])
  make = metadata[:make]
  model = metadata[:model]
  args = ["exiftool", "-P", "-overwrite_original", "-m", "-api", "QuickTimeUTC=1"]

  if image_exts.include?(ext)
    if datetime
      args += [
        "-DateTimeOriginal=#{datetime}", "-CreateDate=#{datetime}", "-ModifyDate=#{datetime}",
        "-XMP:DateCreated=#{datetime}", "-XMP:CreateDate=#{datetime}", "-XMP-photoshop:DateCreated=#{datetime}",
        "-IPTC:DateCreated=#{iptc_date(datetime)}", "-IPTC:TimeCreated=#{iptc_time(datetime)}",
        "-FileModifyDate=#{datetime}", "-FileCreateDate=#{datetime}"
      ]
      args += ["-OffsetTime=#{tz}", "-OffsetTimeOriginal=#{tz}", "-OffsetTimeDigitized=#{tz}"] unless tz.empty?
    end
    if gps
      lat, lon = gps
      args += [
        "-GPSLatitude=#{lat}", "-GPSLongitude=#{lon}",
        "-GPSLatitudeRef=#{lat.to_s.start_with?("-") ? "S" : "N"}",
        "-GPSLongitudeRef=#{lon.to_s.start_with?("-") ? "W" : "E"}",
        "-XMP-exif:GPSLatitude=#{lat}", "-XMP-exif:GPSLongitude=#{lon}"
      ]
    end
    args += ["-IFD0:Make=#{make}", "-XMP-tiff:Make=#{make}"] if make && !make.empty?
    args += ["-IFD0:Model=#{model}", "-XMP-tiff:Model=#{model}"] if model && !model.empty?
  elsif video_exts.include?(ext)
    if datetime
      args += [
        "-QuickTime:CreateDate=#{datetime}", "-QuickTime:MediaCreateDate=#{datetime}",
        "-QuickTime:TrackCreateDate=#{datetime}", "-FileModifyDate=#{datetime}", "-FileCreateDate=#{datetime}"
      ]
    end
    if gps
      lat, lon = gps
      coords = "#{lat}, #{lon}"
      args += ["-Keys:GPSCoordinates=#{coords}", "-UserData:GPSCoordinates=#{coords}"]
    end
    args += ["-Keys:Make=#{make}", "-UserData:Make=#{make}"] if make && !make.empty?
    args += ["-Keys:Model=#{model}", "-UserData:Model=#{model}"] if model && !model.empty?
  end

  args.length > 6 ? args : nil
end

targets = collect_targets(paths, media_exts)
updates = []
if !global_time.empty? || !global_gps.empty? || !global_make.empty? || !global_model.empty?
  targets.each { |target| updates << [target, { time: global_time, gps: global_gps, make: global_make, model: global_model }] }
end

if !metadata_csv.empty?
  CSV.foreach(metadata_csv, headers: true) do |row|
    target = resolve_target(row_value(row, "file", "path", "source", "name"), targets)
    next unless target
    updates << [
      target,
      {
        time: row_value(row, "time", "datetime", "date_time", "capture_time"),
        gps: row_value(row, "gps", "coordinates", "latlon", "lat_lon"),
        lat: row_value(row, "lat", "latitude"),
        lon: row_value(row, "lon", "lng", "longitude"),
        make: row_value(row, "make", "camera_make", "device_make"),
        model: row_value(row, "model", "camera_model", "device_model")
      }
    ]
  end
end

applied = 0
updates.each do |target, metadata|
  args = metadata_args_for(target, metadata, image_exts, video_exts, tz)
  next unless args
  args << target
  if dry_run
    puts "DRY RUN: #{args.shelljoin}"
  else
    system(*args, out: File::NULL) || exit($?.exitstatus || 1)
  end
  applied += 1
end

puts "Manual metadata updates: #{applied} file(s)."
