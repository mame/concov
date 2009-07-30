#!/usr/bin/env ruby19

require "coverage"
require "pathname"

base_dir = Pathname(__FILE__).dirname.dirname.expand_path
$LOAD_PATH.unshift(base_dir.to_s)

specs = ARGV.empty? ? Dir.glob(base_dir.to_s + "/spec/**/*.rb") : ARGV
specs = specs.map {|spec| Pathname(spec).expand_path }
specs = specs.reject {|spec| spec == Pathname(__FILE__).expand_path }

Coverage.start
specs.each do |spec|
  Dir.chdir(base_dir)
  load(spec)
end
Dir.chdir(base_dir)
Coverage.result.each do |src, counts|
  src = Pathname(src).relative_path_from(base_dir)
  next if src.each_filename.first == ".."
  dest = Pathname("cov") + src.dirname + (src.basename.to_s + "cov")
  dest.dirname.mkpath
  dest.open("w") do |file|
    src.each_line.with_index.zip(counts) do |(line, idx), count|
      count = count ? count > 0 ? count.to_s : "#####" : ""
      file.puts "%8s:%4d:%s" % [count, idx + 1, line]
    end
  end
end
