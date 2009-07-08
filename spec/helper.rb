#
# concov - continuous coverage manager
#
#   * spec/helper.rb: spec helper
#

require "stringio"

def setup_sandbox
  base_path = Pathname(Dir.mktmpdir)
  conf_path = base_path + "concov.conf"
  data_path = base_path + "data"
  open(conf_path, "w") do |f|
    f.puts "database_path: #{ data_path }"
  end

  at_exit do
    # purge sandbox
    base_path.rmtree
  end

  [base_path, conf_path]
end

def run_concov(*args)
  stdout = $stdout
  $stdout = StringIO.new
  Concov::Command.main(*args)
  $stdout.string
ensure
  $stdout = stdout
end

def sample_env(path)
  File.dirname(File.dirname(__FILE__)) + "/spec/sample-env/" + path
end
