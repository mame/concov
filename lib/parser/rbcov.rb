#
# concov - continuous coverage manager
#
#   * lib/parser/rbcov.rb: parser for rbcov file
#

module Concov
  class RbcovParser < Parser
    EXT = "rbcov"

    def parse(file)
      notify_path(file.basename(".rbcov").to_s + ".rb")
      file.each_line(encoding: "ASCII-8BIT") do |line|
        if /^\s+(?<count>-|#+|\d+):\s*(?<lineno>\d+):(?<line>.*?$)/ =~ line
          count, lineno = count == "-" ? nil : count.to_i, lineno.to_i
          notify_line(lineno, count, line)
        end
      end
    end
  end
end
