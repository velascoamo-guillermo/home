#!/usr/bin/env ruby
# Usage: ruby scripts/create_uitest_target.rb  (idempotent; run from repo root)
require 'xcodeproj'

proj = Xcodeproj::Project.open('Home.xcodeproj')
if proj.targets.any? { |t| t.name == 'HomeUITests' }
  puts 'HomeUITests already exists'
  exit 0
end

app = proj.targets.find { |t| t.name == 'Home' } or abort 'no Home target'
target = proj.new_target(:ui_test_bundle, 'HomeUITests', :ios, app.deployment_target)
target.add_dependency(app)
target.build_configurations.each do |config|
  config.build_settings['TEST_TARGET_NAME'] = 'Home'
  config.build_settings['SWIFT_VERSION'] = '6.0'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.guillermovelasco.managedhome.HomeUITests'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  # xcodeproj's new_target doesn't set PRODUCT_NAME (unlike Xcode's own target templates);
  # without it, the built .xctest has an empty filename and collides with other PlugIns outputs.
  config.build_settings['PRODUCT_NAME'] = '$(TARGET_NAME)'
end

group = proj.main_group.find_subpath('HomeUITests', true)
group.set_source_tree('<group>')
group.set_path('HomeUITests')
Dir.glob('HomeUITests/*.swift').sort.each do |f|
  ref = group.new_reference(File.basename(f))
  target.add_file_references([ref])
end
proj.save

scheme_path = Xcodeproj::XCScheme.shared_data_dir(proj.path) + 'Home.xcscheme'
scheme = Xcodeproj::XCScheme.new(scheme_path)
scheme.add_test_target(target)
scheme.save!
puts "created HomeUITests with #{target.source_build_phase.files.count} source files"
