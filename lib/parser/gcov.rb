#
# concov - continuous coverage manager
#
#   * lib/parser/gcov.rb: parser for gcov file
#

module Concov
  class GcovParser < Parser
    EXT = "gcov"

    def parse(file)
      file.each_line(encoding: "ASCII-8BIT") do |line|
        if /^\s*(?<count>-|#+|\d+):\s*(?<lineno>\d+):(?<line>.*?$)/ =~ line
          count, lineno = count == "-" ? nil : count.to_i, lineno.to_i
          if lineno == 0
            notify_path($') if /Source:/ =~ line
          else
            notify_line(lineno, count, line)
          end
        end
      end
    end
  end
end
