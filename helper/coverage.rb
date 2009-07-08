#
# concov - continuous coverage manager
#
#   * helper/coverage.rb: coverage markup
#

module Ramaze
  module Helper
    module Coverage
      LEVEL_CLASSES = {
        0.500 * 1 / 3 => "lev0", 0.500 * 2 / 3 => "lev1", 0.500 => "lev2",
        0.625 => "lev3", 0.750 => "lev4", 0.875 => "lev5", 1.000 => "lev6"
      }
      def coverage_markup((hit, found), long = true, opt = {})
        cov, klass1, klass2 = if found && found > 0
          val = hit.quo(found)
          cov = "%3.1f%%" % (100 * val)
          k, klass = LEVEL_CLASSES.find {|k, v| val < k }
          klass ||= "lev7"
          [cov, klass, klass]
        else
          ["N/A", "notice not-available", "not-available"]
        end
        rowspan  = opt[:rowspan ] ? %( rowspan="#{ opt[:rowspan ] }") : ""
        colspan1 = opt[:colspan1] ? %( colspan="#{ opt[:colspan1] }") : ""
        colspan2 = opt[:colspan2] ? %( colspan="#{ opt[:colspan2] }") : ""
        td1 = %(td class="#{ klass1 }"#{ rowspan }#{ colspan1 })
        td2 = %(td class="#{ klass2 }"#{ rowspan }#{ colspan2 })
        if long
          chart = build_bar_chart(hit, found)
          %(<#{ td1 }>#{ chart }#{ cov }</td>) <<
          %(<#{ td2 }>#{ hit } / #{ found }</td>)
        else
          %(<#{ td1 } title="#{ hit } / #{ found }">#{ cov }</td>)
        end
      end
    end
  end
end
