#
# concov - continuous coverage manager
#
#   * lib/command/register.rb: register coverage files to database
#

require "lib/parser"
require "lib/parser/gcov"
require "lib/parser/rbcov"

module Concov
  class Command::Register < Command
    def option(op)
      op.banner = "usage: register COVERAGE_DIR"
      op.separator "gather coverage files and record the coverage to database."
      op.separator nil
      op.separator "Valid options:"
      @date = Date.today
      op.on(
        "-d DATE", "--date DATE", "specify date YYYYmmdd (default: today)"
      ) {|x| @date = Date.parse(x) }
    end

    def run(path)
      progress do |prog|
        Coverage.register(@date, prog) do |new_file|
          covs = {}
          cov = nil
          @base_dir = path = Pathname(path).cleanpath.expand_path

          # traverse target directories and check coverage data file
          enum_cov_file(path) do |cov_file, *args|
            # new coverage data file found
            src = nil

            Parser.parse(cov_file) do |event, *args|
              case event
              when :path
                # original location of the coverage data file found
                path, adapter = args
                path = Pathname(path).expand_path(cov_file.dirname)

                # if the location is out of target dir or in a dir that
                # configuration specifies to ignore, this will be skipped
                break unless path = check_path(path)

                # initialize to capturing coverage data
                cov = (covs[path] ||= [adapter, []]).last
                src = new_file[path]

              when :line
                # new coverage line found
                lineno, count, line = args

                # coverable line unless count is nil
                if count
                  cov[lineno - 1] ||= 0
                  cov[lineno - 1] += count
                end

                # copy the line into database
                src.puts line
              end
            end
            src.close if src
          end
          covs
        end
        prog[nil]
      end
    end

    private

    # traverse the specified dir and yield coverage data file whose extension
    # matches ones of supported coverage measurement tools
    def enum_cov_file(cov_path, &blk)
      unless cov_path.directory?
        Concov.error("path not found: " + cov_path.to_s)
      end
      exts = Parser.supported_extensions.join(",")
      Pathname.glob(cov_path.to_s + "/**/*.{#{ exts }}", &blk)
    end

    # convert path to relative path, and check whether the file should be
    # captured
    def check_path(path)
      # convert
      path = path.relative_path_from(@base_dir)

      # skip the file if it is out of target dir
      return if path.each_filename.first == ".."

      # skip the file if it is specified to skip by configuration
      Config.skip_files.any? {|x| path.fnmatch(x) } ? nil : path
    end

    # progress report for coverage data gathering
    def progress
      prev_msg = nil
      start_time = Time.now

      max_width = 0
      output = ->(msg) do
        max_width = [msg.size, max_width].max
        msg = "\r" + msg + " " * (max_width - msg.size)
        print msg
        $stdout.flush
      end

      yield(->(msg, n = nil, m = nil) do
        if prev_msg && prev_msg != msg
          output["%s: %.1f sec." % [prev_msg, Time.now - start_time]]
          puts
          start_time = Time.now
        end
        prev_msg = msg
        if msg
          msg += "..."
          msg << " #{ n }" if n
          msg << " / #{ m } (#{ (100 * n.quo(m)).to_i }%)" if m
          output[msg]
        end
      end)
    rescue ConcovError
      puts if prev_msg
      raise
    end
  end
end
