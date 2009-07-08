#
# concov - continuous coverage manager
#
#   * lib/parser.rb: abstract parser that parses coverage result files
#

module Concov
  class Parser
    # returns extensions of coverage result file that can be parsed
    def self.supported_extensions
      parsers.keys
    end

    # parses coverage result file
    def self.parse(file, &blk)
      parser = parsers[file.extname[1..-1]]
      catch(:cancel) do
        parser.new(&blk).parse(file)
      end
    end

    private

    @@parsers = {}

    # manage concrete parsers
    def self.inherited(parser)
      (@@parsers[nil] ||= []) << parser
    end

    def self.parsers
      (@@parsers.delete(nil) || []).each do |parser|
        @@parsers[parser::EXT] = parser
      end
      @@parsers
    end

    def initialize(&blk)
      @blk = blk
      @path_notified = false
    end


    protected

    # callback when path of original source code is found
    def notify_path(path)
      @blk.call(:path, path, self.class::EXT)
      @path_notified = true
    end

    # callback when coverage of each line is found
    def notify_line(lineno, count, text)
      unless @path_notified
        Concov.error("path of original source code is not found") 
      end

      @blk.call(:line, lineno, count, text)
    end
  end
end
