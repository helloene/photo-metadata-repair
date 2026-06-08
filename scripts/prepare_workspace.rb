#!/usr/bin/env ruby
require "fileutils"
require "find"
require "pathname"
require "shellwords"

dry_run, output_root, *input_paths = ARGV
dry_run = dry_run == "1"
output_root = File.expand_path(output_root)
media_exts = %w[.jpg .jpeg .heic .png .tif .tiff .mp4 .mov .m4v .3gp]

def media_file?(path, media_exts)
  File.file?(path) && media_exts.include?(File.extname(path).downcase)
end

def unique_destination(path)
  return path unless File.exist?(path)

  ext = File.extname(path)
  base = File.join(File.dirname(path), File.basename(path, ext))
  index = 2
  loop do
    candidate = "#{base}-#{index}#{ext}"
    return candidate unless File.exist?(candidate)
    index += 1
  end
end

def unique_planned_destination(path, used_destinations)
  candidate = unique_destination(path)
  return used_destinations[candidate] = candidate unless used_destinations.key?(candidate)

  ext = File.extname(path)
  base = File.join(File.dirname(path), File.basename(path, ext))
  index = 2
  loop do
    candidate = unique_destination("#{base}-#{index}#{ext}")
    return used_destinations[candidate] = candidate unless used_destinations.key?(candidate)
    index += 1
  end
end

def unique_key_for_input(expanded, used_keys)
  basename = File.basename(expanded)
  parent = File.basename(File.dirname(expanded))
  candidates = [basename, parent.empty? ? basename : "#{parent}-#{basename}", expanded.sub(%r{\A/+}, "").tr("/", "-")]

  candidates.each do |candidate|
    next if candidate.empty? || used_keys.key?(candidate)
    used_keys[candidate] = true
    return candidate
  end

  index = 2
  loop do
    candidate = "#{basename}-#{index}"
    next index += 1 if used_keys.key?(candidate)
    used_keys[candidate] = true
    return candidate
  end
end

prepared_roots = []
used_root_keys = {}
used_destinations = {}

input_paths.each do |input_path|
  expanded = File.expand_path(input_path)

  if File.directory?(expanded)
    output_root_for_input = File.join(output_root, unique_key_for_input(expanded, used_root_keys))
    prepared_roots << output_root_for_input
    Find.find(expanded) do |source|
      if File.directory?(source)
        Find.prune if File.expand_path(source) == output_root
        next
      end
      next unless media_file?(source, media_exts)

      relative = Pathname.new(source).relative_path_from(Pathname.new(expanded)).to_s
      destination = File.join(output_root_for_input, relative)
      if dry_run
        warn "DRY RUN: copy #{source.shellescape} -> #{destination.shellescape}"
      else
        FileUtils.mkdir_p(File.dirname(destination))
        FileUtils.cp(source, destination, preserve: true)
      end
    end
  elsif media_file?(expanded, media_exts)
    destination = unique_planned_destination(File.join(output_root, File.basename(expanded)), used_destinations)
    prepared_roots << destination
    if dry_run
      warn "DRY RUN: copy #{expanded.shellescape} -> #{destination.shellescape}"
    else
      FileUtils.mkdir_p(File.dirname(destination))
      FileUtils.cp(expanded, destination, preserve: true)
    end
  else
    warn "Skipping unsupported input #{input_path}"
  end
end

prepared_roots.uniq.each { |path| puts path }
