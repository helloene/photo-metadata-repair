#!/usr/bin/env ruby
require "csv"
require "open3"

paths = ARGV
image_exts = %w[.jpg .jpeg .heic .png .tif .tiff]
video_exts = %w[.mp4 .mov .m4v .3gp]
ext_args = %w[-ext jpg -ext jpeg -ext heic -ext png -ext tif -ext tiff -ext mp4 -ext mov -ext m4v -ext 3gp]

def conflict_warning(file, field, values)
  message = "CONFLICT: #{field} differs in #{file}; keeping existing values and skipping automatic sync. #{values.map { |key, value| "#{key}=#{value.inspect}" }.join(', ')}"
  warn "\e[41;97;1m #{message} \e[0m"
end

def non_conflicting_value(row, file, field, keys)
  values = keys.map do |key|
    value = row[key]
    next if value.nil? || value.strip.empty?
    [key, value.strip]
  end.compact
  unique_values = values.map(&:last).uniq
  return nil if unique_values.empty?
  if unique_values.length > 1
    conflict_warning(file, field, values)
    return :conflict
  end
  unique_values.first
end

cmd = [
  "exiftool", "-r", "-G1", "-csv", *ext_args,
  "-IFD0:Make", "-IFD0:Model", "-XMP-tiff:Make", "-XMP-tiff:Model",
  "-Keys:Make", "-Keys:Model", "-UserData:Make", "-UserData:Model", *paths
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
    make = non_conflicting_value(row, source, "Make", ["IFD0:Make", "XMP-tiff:Make"])
    model = non_conflicting_value(row, source, "Model", ["IFD0:Model", "XMP-tiff:Model"])
    args += ["-IFD0:Make=#{make}", "-XMP-tiff:Make=#{make}"] if make && make != :conflict
    args += ["-IFD0:Model=#{model}", "-XMP-tiff:Model=#{model}"] if model && model != :conflict
  elsif video_exts.include?(ext)
    make = non_conflicting_value(row, source, "Make", ["Keys:Make", "UserData:Make"])
    model = non_conflicting_value(row, source, "Model", ["Keys:Model", "UserData:Model"])
    args += ["-Keys:Make=#{make}", "-UserData:Make=#{make}"] if make && make != :conflict
    args += ["-Keys:Model=#{model}", "-UserData:Model=#{model}"] if model && model != :conflict
  end
  next if args.length == 4

  args << source
  system(*args, out: File::NULL) || exit($?.exitstatus || 1)
  updated += 1
end

puts "Synchronized device make/model metadata for #{updated} file(s)."
