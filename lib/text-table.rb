#
# concov - continuous coverage manager
#
#   * lib/text-table.rb: text table builder for terminal use
#
#
# example:
#   TextTable.build("rl") do |table|
#     table << ["foo/bar", "baz/qux"]
#     table << [["c", "*"], "@@@"]
#     table << nil
#     table << [123, 456]
#   end
#     #=> +-------+-------+
#         |foo/bar|baz/qux|
#         |   *   |@@@    |
#         +-------+-------+
#         |    123|456    |
#         +-------+-------+
#

module Concov
  class TextTable
    # for ease of use
    def self.build(format)
      i = new(format)
      yield i
      i.to_s
    end

    # take new column
    def <<(column)
      @columns << column
    end

    # create text table
    def to_s
      format_table(@format, @columns)
    end

    private

    # initialize table
    def initialize(format)
      @format = format
      @columns = []
    end

    # format taken columns to table
    def format_table(format, columns)
      widths = columns.compact.transpose.map do |cols|
        cols.map {|x| (x.is_a?(Array) ? x.last : x).to_s.size }.max
      end
      text = []
      bar = "+" + widths.map {|n| "-" * n }.join("+") + "+"
      text << bar
      columns.each do |column|
        text << (column ? format_column(format, widths, column) : bar)
      end
      text << bar
      text.join("\n")
    end

    def format_column(format, widths, column)
      line = format.chars.zip(column, widths).map do |align, elem, width|
        align, elem = *elem if elem.is_a?(Array)
        elem.to_s.send(ALIGN_METHODS[align], width)
      end
      "|" + line.join("|") + "|"
    end
    ALIGN_METHODS = { ?r => :rjust, ?l => :ljust, ?c => :center }
  end
end
