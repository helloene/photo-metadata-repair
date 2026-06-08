#!/usr/bin/env ruby
require "csv"
require "open3"

paths = ARGV
image_exts = %w[.jpg .jpeg .heic .png .tif .tiff]
video_exts = %w[.mp4 .mov .m4v .3gp]
ext_args = %w[-ext jpg -ext jpeg -ext heic -ext png -ext tif -ext tiff -ext mp4 -ext mov -ext m4v -ext 3gp]

def present?(value)
  value && !value.strip.empty?
end

def number(value)
  Float(value) if present?(value)
rescue ArgumentError
  nil
end

def close?(a, b)
  a && b && (a - b).abs < 0.000001
end

def conflict_warning(file, field, values)
  message = "CONFLICT: #{field} differs in #{file}; keeping existing values and skipping automatic sync. #{values.map { |key, value| "#{key}=#{value.inspect}" }.join(', ')}"
  warn "\e[41;97;1m #{message} \e[0m"
end

def parse_coordinate_pair(value)
  return nil unless present?(value)
  text = value.strip
  numeric_parts = text.scan(/[-+]?\d+(?:\.\d+)?/)
  return nil unless numeric_parts.length >= 2
  lat = number(numeric_parts[0])
  lon = number(numeric_parts[1])
  return nil unless lat && lon
  lat = -lat.abs if text =~ /\bS\b/i
  lon = -lon.abs if text =~ /\bW\b/i
  lat = lat.abs if text =~ /\bN\b/i
  lon = lon.abs if text =~ /\bE\b/i
  [lat, lon]
end

cmd = [
  "exiftool", "-r", "-n", "-G1", "-csv", *ext_args,
  "-GPS:GPSLatitude", "-GPS:GPSLongitude",
  "-XMP-exif:GPSLatitude", "-XMP-exif:GPSLongitude",
  "-Keys:GPSCoordinates#", "-UserData:GPSCoordinates#", *paths
]

stdout, stderr, status = Open3.capture3(*cmd)
unless status.success?
  warn stderr
  exit status.exitstatus || 1
end

updated = 0
CSV.parse(stdout, headers: true).each do |row|
  source = row["SourceFile"]
  next unless source && File.file?(source)

  ext = File.extname(source).downcase
  args = ["exiftool", "-P", "-overwrite_original", "-m"]
  if image_exts.include?(ext)
    exif_lat = number(row["GPS:GPSLatitude"])
    exif_lon = number(row["GPS:GPSLongitude"])
    xmp_lat = number(row["XMP-exif:GPSLatitude"])
    xmp_lon = number(row["XMP-exif:GPSLongitude"])
    has_exif = exif_lat && exif_lon
    has_xmp = xmp_lat && xmp_lon
    if has_exif && has_xmp && (!close?(exif_lat, xmp_lat) || !close?(exif_lon, xmp_lon))
      conflict_warning(source, "GPS", {
        "GPS:GPSLatitude" => row["GPS:GPSLatitude"],
        "GPS:GPSLongitude" => row["GPS:GPSLongitude"],
        "XMP-exif:GPSLatitude" => row["XMP-exif:GPSLatitude"],
        "XMP-exif:GPSLongitude" => row["XMP-exif:GPSLongitude"]
      })
      next
    elsif has_exif && !has_xmp
      args += ["-XMP-exif:GPSLatitude=#{exif_lat}", "-XMP-exif:GPSLongitude=#{exif_lon}"]
    elsif has_xmp && !has_exif
      args += [
        "-GPSLatitude=#{xmp_lat}", "-GPSLongitude=#{xmp_lon}",
        "-GPSLatitudeRef=#{xmp_lat.negative? ? "S" : "N"}",
        "-GPSLongitudeRef=#{xmp_lon.negative? ? "W" : "E"}"
      ]
    end
  elsif video_exts.include?(ext)
    keys = row["Keys:GPSCoordinates#"] || row["Keys:GPSCoordinates"]
    user_data = row["UserData:GPSCoordinates#"] || row["UserData:GPSCoordinates"]
    keys_coords = parse_coordinate_pair(keys)
    user_data_coords = parse_coordinate_pair(user_data)
    if keys_coords && user_data_coords
      unless close?(keys_coords[0], user_data_coords[0]) && close?(keys_coords[1], user_data_coords[1])
        conflict_warning(source, "GPSCoordinates", { "Keys:GPSCoordinates" => keys, "UserData:GPSCoordinates" => user_data })
        next
      end
    elsif keys_coords && !user_data_coords
      args += ["-UserData:GPSCoordinates=#{keys_coords.join(', ')}"]
    elsif user_data_coords && !keys_coords
      args += ["-Keys:GPSCoordinates=#{user_data_coords.join(', ')}"]
    end
  end
  next if args.length == 4

  args << source
  system(*args, out: File::NULL) || exit($?.exitstatus || 1)
  updated += 1
end

puts "Synchronized GPS metadata for #{updated} file(s); conflicting GPS values were preserved."
