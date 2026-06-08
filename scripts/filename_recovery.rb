#!/usr/bin/env ruby
require "csv"
require "open3"
require "time"

tz, tz_provided, dry_run, assume_yes, *paths = ARGV
tz_provided = tz_provided == "1"
dry_run = dry_run == "1"
assume_yes = assume_yes == "1"
parse_tz = tz_provided ? tz : "+00:00"

EXT_ARGS = %w[-ext jpg -ext jpeg -ext heic -ext png -ext tif -ext tiff -ext mp4 -ext mov -ext m4v -ext 3gp].freeze
IMAGE_EXTS = %w[.jpg .jpeg .heic .png .tif .tiff].freeze
VIDEO_EXTS = %w[.mp4 .mov .m4v .3gp].freeze

def valid_datetime?(year, month, day, hour, minute, second)
  year = year.to_i
  month = month.to_i
  day = day.to_i
  hour = hour.to_i
  minute = minute.to_i
  second = second.to_i
  return false unless year.between?(1970, 2099)
  return false unless hour.between?(0, 23) && minute.between?(0, 59) && second.between?(0, 59)

  Time.new(year, month, day, hour, minute, second)
  true
rescue ArgumentError
  false
end

def exif_datetime(year, month, day, hour, minute, second)
  format("%04d:%02d:%02d %02d:%02d:%02d", year.to_i, month.to_i, day.to_i, hour.to_i, minute.to_i, second.to_i)
end

def iptc_date(datetime)
  datetime[0, 10].delete(":")
end

def iptc_time(datetime)
  datetime[11, 8]
end

def unix_timestamp_candidate(stem, tz)
  stem.scan(/(?<!\d)(\d{10}|\d{13})(?!\d)/).flatten.each do |stamp|
    seconds = stamp.length == 13 ? stamp.to_i / 1000.0 : stamp.to_i
    time = Time.at(seconds).getlocal(tz)
    next unless time.year.between?(1970, 2099)

    return {
      rule: stamp.length == 13 ? "Unix Time (milliseconds)" : "Unix Time (seconds)",
      description: stamp.length == 13 ? "13-digit Unix time in milliseconds" : "10-digit Unix time in seconds",
      datetime: time.strftime("%Y:%m:%d %H:%M:%S")
    }
  rescue ArgumentError, RangeError
    next
  end
  nil
end

def parse_filename_time(filename, tz)
  stem = File.basename(filename, File.extname(filename))
  candidates = []
  unix_candidate = unix_timestamp_candidate(stem, tz)
  candidates << unix_candidate if unix_candidate

  patterns = [
    ["YYYYMMDDHHMMSS", /(?<!\d)((?:19|20)\d{2})(0[1-9]|1[0-2])(0[1-9]|[12]\d|3[01])([01]\d|2[0-3])([0-5]\d)([0-5]\d)(?!\d)/, "compact 14-digit timestamp"],
    ["YYYYMMDD_HHMMSS", /(?<!\d)((?:19|20)\d{2})(0[1-9]|1[0-2])(0[1-9]|[12]\d|3[01])[\s_.-]+([01]\d|2[0-3])([0-5]\d)([0-5]\d)(?!\d)/, "8-digit date plus 6-digit time"],
    ["YYYY-MM-DD_HH-MM-SS", /(?<!\d)((?:19|20)\d{2})[-_.](0[1-9]|1[0-2])[-_.](0[1-9]|[12]\d|3[01])(?:[T\s_.-]+)([01]\d|2[0-3])[-_.:]?([0-5]\d)[-_.:]?([0-5]\d)(?!\d)/, "separated date and time"]
  ]

  patterns.each do |rule, regexp, description|
    stem.scan(regexp) do |year, month, day, hour, minute, second|
      next unless valid_datetime?(year, month, day, hour, minute, second)
      candidates << { rule: rule, description: description, datetime: exif_datetime(year, month, day, hour, minute, second) }
    end
  end

  candidates.uniq { |candidate| [candidate[:rule], candidate[:datetime]] }
end

def concrete_time?(value)
  value && !value.strip.empty? && value !~ /^0{4}:0{2}:0{2}/
end

cmd = [
  "exiftool", "-r", "-csv", *EXT_ARGS, "-FileName", "-Directory",
  "-DateTimeOriginal", "-CreateDate", "-ModifyDate",
  "-QuickTime:CreateDate", "-QuickTime:MediaCreateDate", "-QuickTime:TrackCreateDate",
  *paths
]

stdout, stderr, status = Open3.capture3(*cmd)
unless status.success?
  warn stderr
  exit status.exitstatus || 1
end

proposals = []
skipped_existing = 0
skipped_unmatched = 0
skipped_ambiguous = 0

CSV.parse(stdout, headers: true).each do |row|
  source = row["SourceFile"]
  next unless source && File.file?(source)

  ext = File.extname(source).downcase
  media_type = IMAGE_EXTS.include?(ext) ? :image : (VIDEO_EXTS.include?(ext) ? :video : nil)
  next unless media_type

  embedded_fields = media_type == :image ? [row["DateTimeOriginal"], row["CreateDate"], row["ModifyDate"]] : [row["CreateDate"], row["MediaCreateDate"], row["TrackCreateDate"]]
  if embedded_fields.any? { |value| concrete_time?(value) }
    skipped_existing += 1
    next
  end

  candidates = parse_filename_time(row["FileName"] || File.basename(source), parse_tz)
  if candidates.empty?
    skipped_unmatched += 1
    next
  end

  datetimes = candidates.map { |candidate| candidate[:datetime] }.uniq
  rules = candidates.map { |candidate| candidate[:rule] }.uniq
  if datetimes.length != 1 || rules.length != 1
    skipped_ambiguous += 1
    next
  end

  candidate = candidates.first
  proposals << { file: source, media_type: media_type, rule: candidate[:rule], description: candidate[:description], datetime: candidate[:datetime] }
end

if proposals.empty?
  puts "No missing embedded capture times could be filled from supported filename timestamp rules."
  puts "Skipped: #{skipped_existing} already had embedded time, #{skipped_unmatched} had no supported filename time, #{skipped_ambiguous} were ambiguous."
  exit 0
end

groups = proposals.group_by { |proposal| proposal[:rule] }
puts "Filename timestamp preflight:"
puts "  Proposed writes: #{proposals.length}"
puts "  Rules found: #{groups.length}"
puts "  Skipped: #{skipped_existing} already had embedded time, #{skipped_unmatched} had no supported filename time, #{skipped_ambiguous} were ambiguous."
puts
groups.sort_by { |rule, _items| rule }.each do |rule, items|
  sample = items.sample
  puts "- #{rule} (#{sample[:description]}): #{items.length} file(s)"
  puts "  sample: #{File.basename(sample[:file])} -> #{sample[:datetime]}"
end
puts

unless tz_provided
  warn "--from-filename-if-missing requires an explicit --tz when filename-derived timestamps would be written."
  warn "Filenames do not carry timezone information, so rerun with a timezone such as --tz +08:00 or --tz +00:00."
  exit 2
end

if dry_run
  puts "Dry run only: filename-derived timestamps were not written."
  exit 0
end

unless assume_yes
  print "Write these filename-derived timestamps? Type yes to continue: "
  answer = STDIN.gets&.strip
  unless answer == "yes"
    puts "Aborted before writing filename-derived timestamps."
    exit 2
  end
end

proposals.each do |proposal|
  datetime = proposal[:datetime]
  args = ["exiftool", "-P", "-overwrite_original", "-m", "-api", "QuickTimeUTC=1"]
  if proposal[:media_type] == :image
    args += [
      "-DateTimeOriginal=#{datetime}", "-CreateDate=#{datetime}", "-ModifyDate=#{datetime}",
      "-XMP:DateCreated=#{datetime}", "-XMP:CreateDate=#{datetime}", "-XMP-photoshop:DateCreated=#{datetime}",
      "-IPTC:DateCreated=#{iptc_date(datetime)}", "-IPTC:TimeCreated=#{iptc_time(datetime)}",
      "-OffsetTime=#{tz}", "-OffsetTimeOriginal=#{tz}", "-OffsetTimeDigitized=#{tz}",
      "-FileModifyDate=#{datetime}", "-FileCreateDate=#{datetime}"
    ]
  else
    args += [
      "-QuickTime:CreateDate=#{datetime}", "-QuickTime:MediaCreateDate=#{datetime}",
      "-QuickTime:TrackCreateDate=#{datetime}", "-FileModifyDate=#{datetime}", "-FileCreateDate=#{datetime}"
    ]
  end
  args << proposal[:file]
  system(*args, out: File::NULL) || exit($?.exitstatus || 1)
end

puts "Wrote filename-derived timestamps to #{proposals.length} file(s)."
