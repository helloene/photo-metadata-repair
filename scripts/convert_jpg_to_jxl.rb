#!/usr/bin/env ruby
require "find"
require "fileutils"
require "shellwords"

dry_run, overwrite_jxl, replace_jpg_with_jxl, *paths = ARGV
dry_run = dry_run == "1"
overwrite_jxl = overwrite_jxl == "1"
replace_jpg_with_jxl = replace_jpg_with_jxl == "1"

def jpeg_file?(path)
  File.file?(path) && [".jpg", ".jpeg"].include?(File.extname(path).downcase)
end

def output_path_for(path)
  File.join(File.dirname(path), "#{File.basename(path, File.extname(path))}.jxl")
end

inputs = []
paths.each do |path|
  expanded = File.expand_path(path)
  if File.directory?(expanded)
    Find.find(expanded) { |item| inputs << item if jpeg_file?(item) }
  elsif jpeg_file?(expanded)
    inputs << expanded
  end
end

converted = 0
skipped = 0
failed = 0
replaced = 0

inputs.sort.each do |input|
  output = output_path_for(input)
  if File.exist?(output) && !overwrite_jxl
    puts "Skipping existing #{output}"
    skipped += 1
    next
  end

  cmd = ["cjxl", input, output, "--lossless_jpeg=1", "--container=1", "--quiet"]
  if dry_run
    puts "DRY RUN: #{cmd.shelljoin}"
    puts "DRY RUN: rm #{input.shellescape}" if replace_jpg_with_jxl
    converted += 1
    next
  end

  FileUtils.mkdir_p(File.dirname(output))
  unless system(*cmd)
    warn "Failed to convert #{input}"
    failed += 1
    next
  end

  stat = File.stat(input)
  File.utime(stat.atime, stat.mtime, output)
  unless system("exiftool", "-P", "-overwrite_original", "-TagsFromFile", input, "-FileCreateDate", "-FileModifyDate", output, out: File::NULL)
    warn "Failed to sync filesystem dates to #{output}"
    failed += 1
    next
  end

  if replace_jpg_with_jxl
    FileUtils.rm_f(input)
    replaced += 1
  end
  converted += 1
end

puts "JPEG XL conversion summary: #{converted} converted, #{replaced} JPEG files removed, #{skipped} skipped, #{failed} failed."
exit 1 if failed.positive?
