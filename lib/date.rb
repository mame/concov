#
# concov - continuous coverage manager
#
#   * lib/date.rb: Date class extension
#

require "date"
require "lib/error"

# Date#strftime and Date#parse are very slow, so there provides faster
# format-specific methods.

module Concov
  module DateInstanceExt
    # show format: `YY/mm/dd'
    def to_show
      "%04d/%02d/%02d" % [year, month, day]
    end

    def to_show_until(date)
      str = nil
      str = (str || "") + "%04d/" % date.year  if str || year  != date.year
      str = (str || "") + "%02d/" % date.month if str || month != date.month
      str = (str || "") + "%02d"  % date.day   if str || day   != date.day
      str = str ? " - " + str : ""
      to_show << str
    end

    # path foramt: `YYmmdd'
    def to_path
      "%04d%02d%02d" % [year, month, day]
    end
  end

  module DateClassExt
    def from_show(str)
      unless %r(\A(?<year>\d{4})/(?<month>\d{2})/(?<day>\d{2})\z) =~ str
        Concov.error("invalid date foramt (YY/mm/dd)")
      end
      Date.new(year.to_i, month.to_i, day.to_i)
    end
    def from_path(str)
      unless %r(\A(?<year>\d{4})(?<month>\d{2})(?<day>\d{2})\z) =~ str
        Concov.error("invalid date foramt (YY/mm/dd)")
      end
      Date.new(year.to_i, month.to_i, day.to_i)
    end
  end

  DATE_PATH_RE = /\d{8}/
end

class Date
  include Concov::DateInstanceExt
  extend Concov::DateClassExt
end
