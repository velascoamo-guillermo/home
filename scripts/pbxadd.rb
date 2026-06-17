#!/usr/bin/env ruby
# Usage: ruby scripts/pbxadd.rb <group/path> <Filename.swift> <TargetName>
# Example: ruby scripts/pbxadd.rb Home/Stock Supermarket.swift Home
require 'xcodeproj'

group_path, filename, target_name = ARGV
abort "usage: pbxadd.rb <group/path> <Filename.swift> <Target>" unless group_path && filename && target_name

abort "file not found: #{filename}" unless File.exist?(filename)

proj   = Xcodeproj::Project.open('Home.xcodeproj')
target = proj.targets.find { |t| t.name == target_name } or abort "no target #{target_name}"

group = proj.main_group
group_path.split('/').each do |seg|
  group = group[seg] || group.new_group(seg, seg)
end

if group.files.any? { |f| f.display_name == filename }
  puts "already registered: #{filename}"
else
  ref = group.new_reference(filename)
  target.add_file_references([ref])
  puts "added #{group_path}/#{filename} to #{target_name}"
  proj.save
end
