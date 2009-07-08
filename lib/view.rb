#
# concov - continuous coverage manager
#
#   * lib/view.rb: temporal views
#

module Concov
  # abstract temporal view class
  #
  # concrete classes should implement `to_dates' method and manage current date
  # as instance variable `@date'.
  class View
    # parse a string representing a view
    def self.parse(s)
      @@view_classes.find do |klass|
        view =
          if klass.respond_to?(:try_parse)
            klass.try_parse(s)
          elsif !view && /\A#{ klass::MARK }(#{ DATE_PATH_RE })\z/ =~ s
            klass.new(Date.from_path($1))
          end
        return view if view
      end
      Concov.error("invalid view format")
    end

    # return current date
    attr_reader :date

    # enumerate each date
    def each(&blk)
      to_dates.each(&blk)
    end
    include Enumerable

    # convertions
    def to_day_view    ; DayView.new(@date); end
    def to_week_view   ; WeekView.new(@date); end
    def to_diff_view   ; DiffView.new(@date - 1, @date); end
    def to_changes_view; ChangesView.new(@date); end
    def to_chart_view  ; ChartView.new(@date); end

    # return a first day of the month
    def first_day
      @date - @date.mday + 1
    end

    # equality
    def hash; @date.hash; end
    def eql?(other); @date == other.date && self.class == other.class; end
    alias == eql?

    # return representation for path
    def to_path
      self.class::MARK + @date.to_path
    end

    # return human-friendly representation
    def to_show
      @date.to_show
    end

    # return related views
    def related_views(first, last)
      related_views_core(first, @date, last) {|date| self.class.new(date) }
    end

    # default to_dates
    def to_dates; [@date]; end

    private

    # return array consisting of first day, previous week, previous day, next
    # day, next week and latest day
    def related_views_core(first, date, last)
      [first, date - 7, date - 1, date + 1, date + 7, last].map do |date|
        yield(date) if date_in_range?(first, date, last)
      end
    end

    # default initializer
    def initialize(date); @date = date; end

    # whether given date can be current date
    def date_in_range?(first, date, last)
      first <= date && date <= last
    end

    @@view_classes ||= []

    # manage concrete view classes
    def self.inherited(view_klass)
      @@view_classes << view_klass
    end
  end

  #
  # possible combinations of mode and view:
  #
  #    view\mode| dir | file
  #   ----------+-----+------
  #    day      |  o  |  o
  #    week     |  o  |  x
  #    diff     |  o  |  o
  #    changes  |  o  |  o
  #    chart    |  o  |  o
  #

  # day view (can be used with both dir and file mode)
  class DayView < View
    MARK = ""
  end

  # week view (can be used with dir mode only)
  class WeekView < View
    MARK = "w"
    def to_dates; (@date - 6..@date); end
    def to_show
      (@date - 6).to_show_until(@date)
    end
    def date_in_range?(first, date, last)
      first <= date && date - 6 <= last
    end
  end

  # diff view (can be used with both dir and file mode)
  class DiffView < View
    def to_dates; [@base, @date]; end
    def self.try_parse(s)
      case s
      when /\Ad(#{ DATE_PATH_RE })\z/
        new(Date.from_path($1) - 1, Date.from_path($1))
      when /\A(#{ DATE_PATH_RE })d(#{ DATE_PATH_RE })\z/
        new(Date.from_path($1), Date.from_path($2))
      end
    end

    # equality
    def hash; [@base, @date].hash; end
    def eql?(other)
      other.class == DiffView && @base == other.base && @date == other.date
    end
    alias == eql?

    attr_reader :base
    def initialize(base = nil, date)
      @base = base || date - 1
      @date = date
    end
    def to_path
      (@base + 1 == @date ? "" : @base.to_path) << "d" << @date.to_path
    end
    def related_views(first, last, type)
      if type == :base
        related_views_core(first, @base, last) do |date|
          date == @date ? DayView.new(date) : DiffView.new(date, @date)
        end
      else
        related_views_core(first, @date, last) do |date|
          @base == date ? DayView.new(date) : DiffView.new(@base, date)
        end
      end
    end

    def to_show(type = nil)
      case type
      when :base then @base.to_show
      when :date then @date.to_show
      else @date.to_show + " (cf. #{ @base.to_show })"
      end
    end
  end

  # changes view (can be used with file mode only)
  class ChangesView < View
    MARK = "c"
    def each
      Concov.error("changes view cannot enumerate")
    end
  end

  # chart view (can be used with both dir and file mode)
  class ChartView < View
    MARK = "g"
    def each
      Concov.error("chart view cannot enumerate")
    end
  end
end
