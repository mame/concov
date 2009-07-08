#
# concov - continuous coverage manager
#
#   * lib/command/view.rb: simple command-line coverage viewer
#

require "lib/date"
require "lib/view"
require "lib/text-table"
require "lib/snipper"

module Concov
  class Command::View < Command
    def option(op)
      op.banner = "usage: view [PATH]"
      op.separator "show coverage summary"
      op.separator nil
      op.separator "Valid options:"

      @opt = {}
      @view = nil

      op.on(
        "-d DATE", "--date DATE", "specify date or range (default: last date)"
      ) {|x| @view = View.parse(x) }

      # not implemented yet
      #op.on("-f COND", "--filter COND", "filter COND") {|x| @opt = x }
    end

    def run(*paths)
      start_time = Time.now

      if paths.size > 1
        Concov.error("wrong number of arguments; see help for usage")
      end
      path = paths.first || ""

      @view = DayView.new(Coverage.last_date(@opt)) unless @view

      @path = Pathname(path).cleanpath
      @path_type = Coverage.path_type(@path, @opt)
      Concov.error("unknown path") unless @path_type

      first_day = @view.first_day
      range = first_day << 2 .. first_day >> 1
      @history = Coverage.history(@path_type, @path, range, @opt)

      result = case @view
      when DayView, WeekView, DiffView
        @path_type != :file ? view_dir : view_file
      when ChangesView then view_changes
      when ChartView   then view_chart
      end

      puts "  date: #{ @view.to_show }"
      puts
      puts result.gsub(/^/, "  ")
      puts
      puts "  elipsed time: %.1f sec." % (Time.now - start_time)
    end


    private

    ##
    ##  format methods
    ##

    # handling directory or file list
    def view_dir
      size = @view.to_dates.to_a.size
      format = "l" + "rrr" * size
      TextTable.build(format) do |table|
        type = @path_type == :dir ? "files" : "dirs"
        table << [[?c, type]] + [[?c, "%"], "", ""] * size << nil
        Coverage.list(@path, @view.to_dates, @opt) do |dir, hash|
          column = @view.map do |date|
            hit, found = hash[date]
            if hit
              cov = found > 0 ? "%3.1f%%" % (100 * hit.quo(found)) : "N/A"
              [cov, "%d" % hit, "%d" % found]
            else
              ["N/A"] * 3
            end
          end.flatten(1)
          table << [dir] + column
        end
      end
    end

    # handling file view
    def view_file
      Concov.error("cannot view file in week view") if @view.is_a?(WeekView)
      unless @view.to_dates.all? {|date| @history.key?(date) }
        Concov.error("invalid date")
      end
      snip = Snipper.new(3) do |snip|
        Coverage.code(@path, *@view) do |(lineno, *ary), output|
          ary = ary.each_slice(2).map do |count, line|
            [count, expand_tab(line || "")]
          end.flatten(1)
          snip.add([lineno, *ary], output)
        end
      end

      snipped = SNIPPED_COLUMNS
      snipped = snipped.map {|h, *l| [h] + l * 2 } if @view.is_a?(DiffView)

      TextTable.build(@view.is_a?(DayView) ? "rrl" : "rrlrl") do |table|
        snip.each_hunk do |output, hunk|
          (output ? hunk : snipped).each {|line| table << line }
        end
      end
    end
    SNIPPED_COLUMNS = [
      [""] * 3,
      [""] * 3,
      ["*", "*", "*** snip ***"].map {|s| [?c, s] },
      [""] * 3,
      [""] * 3,
    ]

    # handling changes
    def view_changes
      buff = []
      columns = Coverage.changes(99999, @path_type, @path, @view.date, @opt)

      format = ->(count, kind, event) do
        next if count == 0
        kind = kind + "s" if count > 1
        buff << "  | #{ count } #{ kind } #{ event }"
      end

      columns.each do |type, *args|
        case type
        when :entry
          date1, date2, hit, found, mark = *args
          title = date2 ? date1.to_show_until(date2 - 1) : date1.to_show + " -"
          cov = found > 0 ? "%3.1f%%" % (100 * hit.quo(found)) : "N/A"
          mark = " (#{ mark })" if mark
          buff << "#{ title }#{ mark }  (#{ cov }; #{ hit }/#{ found })"

        when :diff
          buff << "  ^"
          date1, date2, change = *args
          if @path_type != :file
            format[change[:created ], "file", "added"]
            format[change[:deleted ], "file", "deleted"]
            format[change[:modified], "file", "modified"]
          else
            format[change[:code_inc], "line", "added"]
            format[change[:code_dec], "line", "deleted"]
          end
          buff << "  |"
        end
      end
      buff.join("\n")
    end

    # handling chart
    def view_chart
      Concov.error("chart mode cannot be used in command-line interface")
    end


    # helper
    def expand_tab(line)
      n = 0
      line.gsub(/\t/) { m = 8 - ($~.begin(0) + n) % 8; n += m - 1; " " * m }
    end
  end
end
