#
# concov - continuous coverage manager
#
#   * helper/chart.rb: chart builder (GoogleChart)
#

module Ramaze
  module Helper
    module Chart
      ary = [*"A".."Z", *"a".."z", *"0".."9", "-", "."]
      TABLE = ary.product(ary).map {|c1, c2| c1 + c2 }

      def build_timeline_chart(history, first, last, view, opt)
        # convert plot data
        data = (first..last).map do |date|
          hit, found = history[date]
          hit ? TABLE[((TABLE.size - 1) * hit.quo(found)).round] : "__"
        end.join

        # marks of current view
        mark = []
        vertical = ->(date) do
          mark << "V,ff3333,0,#{ (date - first).round },1,-1"
        end
        range = ->(range) do
          s1, s2 = [range.begin, range.end].map do |date|
            "%.5f" % (date - first).quo(last - first)
          end
          mark << "R,ffcccc,0,#{ s1 },#{ s2 }"
        end
        case view
        when Concov::DayView, Concov::ChangesView, Concov::ChartView
          vertical[view.date]
        when Concov::WeekView
          range[view.to_dates]
        when Concov::DiffView
          vertical[view.base]
          vertical[view.date]
        end

        # labels
        labels, idxs = [], []
        (first..last).each.with_index do |date, idx|
          next unless date.day == 1
          labels << date.to_show
          idxs << idx
        end

        param = []
        # chart size
        param << "chs=#{ opt[:size] }"
        # chart type: line chart
        param << "cht=lc"
        # data format: extended encoding
        param << "chd=e:#{ data }"
        # chart colors
        param << "chco=333399|33cc33"
        # axis type (0:y, 1:x)
        param << "chxt=y,x"
        # grid lines (representing week or month change)
        param << "chg=%.1f,20" % (100.0 / opt[:split])
        # axis labels
        param << "chxl=0:|0|20|40|60|80|100|1:|#{ labels.join("|") }"
        # axis label positions
        param << "chxp=1,#{ idxs.join(",") }"
        # axis range
        param << "chxr=0,0,4095|1,#{ idxs.first },#{ idxs.last }"
        # data point labels (representing current view)
        param << "chm=#{ mark.join("|") }"
        # title
        param << "chtt=#{ opt[:title] }" if opt[:title]
        uri = "http://chart.apis.google.com/chart?#{ param.join("&") }"
        %(<img class="#{ opt[:class] }" src="#{ h(uri) }" />)
      end

      def build_bar_chart(hit, found)
        return if !found || found == 0
        data = [100 * hit.quo(found), 100 * (found - hit).quo(found)]

        param = []
        # chart size
        param << "chs=80x10"
        # chart type: bar chart
        param << "cht=bhs"
        # data format: extended encoding
        param << "chd=t:%.1f|%.1f" % data
        # chart colors
        param << "chco=00ff00,ff0000"
        # bar width
        param << "chbh=10,0,0"
        uri = "http://chart.apis.google.com/chart?#{ param.join("&") }"
        %(<div class="bar-wrap-wrap">) <<
        %(<div class="bar-wrap">) <<
        %(<img class="bar" src="#{ h(uri) }"></img>) <<
        %(</div>) <<
        %(</div>)
      end

      def build_o_meter(hit, found)
        param = []
        # chart size
        param << "chs=80x40"
        # chart type: bar chart
        param << "cht=gom"
        # data format: extended encoding
        param << "chd=t:%.1f" % (100 * hit.quo(found))
        uri = "http://chart.apis.google.com/chart?#{ param.join("&") }"
        %(<img class="o-meter" src="#{ h(uri) }" />)
      end
    end
  end
end

