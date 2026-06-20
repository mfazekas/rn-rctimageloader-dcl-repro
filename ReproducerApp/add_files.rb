gems = "/opt/homebrew/Cellar/cocoapods/1.16.2_2/libexec/gems"
Dir.glob(File.join(gems, "*", "lib")).each { |d| $LOAD_PATH.unshift d }
require "xcodeproj"

proj_path = "ios/ReproducerApp.xcodeproj"
proj = Xcodeproj::Project.open(proj_path)
target = proj.targets.find { |t| t.name == "ReproducerApp" }
raise "target not found" unless target

group = proj.main_group
def ensure_ref(group, path)
  group.files.find { |f| f.path == path } || group.new_reference(path)
end

mm = ensure_ref(group, "ReproducerApp/DCLStress.mm")
ensure_ref(group, "ReproducerApp/DCLStress.h")
ensure_ref(group, "ReproducerApp/ReproducerApp-Bridging-Header.h")

unless target.source_build_phase.files_references.include?(mm)
  target.add_file_references([mm])
end

target.build_configurations.each do |c|
  c.build_settings["SWIFT_OBJC_BRIDGING_HEADER"] = "ReproducerApp/ReproducerApp-Bridging-Header.h"
  c.build_settings["CLANG_ENABLE_MODULES"] = "YES"
end

proj.save
puts "added DCLStress to target ReproducerApp; bridging header set"
puts "sources now: " + target.source_build_phase.files_references.map { |f| f.path }.compact.grep(/DCLStress/).join(", ")
