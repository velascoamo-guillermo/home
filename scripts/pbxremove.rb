#!/usr/bin/env ruby
# Usage: ruby scripts/pbxremove.rb <Filename.swift>
require 'xcodeproj'

filename = ARGV[0] or abort "usage: pbxremove.rb <Filename.swift>"
proj = Xcodeproj::Project.open('Home.xcodeproj')

removed = false
proj.files.select { |f| f.display_name == filename }.each do |ref|
  proj.targets.each do |t|
    t.source_build_phase.files.select { |bf| bf.file_ref == ref }.each do |bf|
      t.source_build_phase.remove_build_file(bf)
    end
  end
  ref.remove_from_project
  puts "removed #{filename}"
  removed = true
end

unless removed
  warn "not found in project: #{filename}"
  exit 1
end

proj.save
