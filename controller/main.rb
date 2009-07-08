#
# concov - continuous coverage manager
#
#   * controller/main.rb: concov web interface
#

require "lib/date"
require "lib/view"
require "lib/snipper"
require "model/coverage"

module Concov
  class MainController < Ramaze::Controller
    # ramaze configuration
    layout(:page) { !request.xhr? }
    engine :ERB
    helper :code
    helper :coverage
    helper :chart
    helper :icon

    CWD = Pathname(".")

    # entrance
    def index(view_str = nil, *path_strs)
      # time measurement starts
      @start_time = Time.now

      # setup parameters
      setup_basic
      setup_opt
      setup_view(view_str)
      setup_path(path_strs)
      setup_history
      setup_guide

      # main dispatch
      case @view
      when DayView, WeekView, DiffView
        @path_type != :file ? view_dir : view_file
      when ChangesView then view_changes
      when ChartView   then view_chart
      end

    rescue ConcovError => e
      @error = e.message
    end


    private

    ##
    ##  parameter setup methods
    ##

    def setup_basic
      @first_date = Coverage.first_date
      @last_date = Coverage.last_date
      unless @first_date
        Concov.error("coverage tree is not registered yet")
      end

    rescue
      unless Coverage.initialized?
        Concov.error("database is not initialized")
      end
    end

    # filtering condition
    def setup_opt
      @opt = {}
      [:adapter, :ext, :incl, :excl].each do |k|
        @opt[k] = request[k] if request[k].to_s != ""
      end
    end

    # current view
    def setup_view(view_str)
      @view = view_str ? View.parse(view_str) : DayView.new(@last_date)
      Concov.error("no data found; please register first") unless @first_date
    end

    # current path
    def setup_path(path_strs)
      @path = Pathname(File.join(*path_strs)).cleanpath
      @path_type = Coverage.path_type(@path, @opt)
    end

    # current history
    def setup_history
      first_day = @view.first_day
      s1, s2 = @view.is_a?(ChartView) ? [3, 3] : [2, 1]
      range = first_day << s1 .. first_day >> s2
      @history = Coverage.history(@path_type, @path, range, @opt)
    end

    # current guide
    def setup_guide
      # XXX: need refactoring and design consideration

      # title
      path = case @path_type
      when :top  then "/"
      when :dir  then @path.to_s + "/"
      else @path.to_s
      end
      @title = "#{ path } - #{ @view.to_show }"

      # logo
      @logo =
        link(%(<img class="logo" src="/concov.png" alt="concov logo" />),
          view: DayView.new(@last_date),
          path: CWD,
          no_opt: true
        )

      # date
      link = ->(str, view) { link(str, view: view) }
      ary = (@view.is_a?(DiffView) ? [[:base], [:date]] : [[]]).map do |type|
        views = @view.related_views(@first_date, @last_date, *type)
        icons = date_navi_icons(views)
        navis = icons.zip(views).map do |icon, view|
          view ? link(icon, view: view) : icon
        end
        [navis[0, 3], @view.to_show(*type), navis[3, 3]].join(" ")
      end
      if @view.is_a?(DiffView)
        @desc_date1, @desc_date2 = ary
        @desc_date =
          %(<span class="side">left: </span>#{ @desc_date1 }<br />) <<
          %(<span class="side">right: </span>#{ @desc_date2 })
      else
        @desc_date = ary.first
      end

      # path
      root_link = link("[root]", path: CWD)
      @desc_path = case @path_type
      when :top
        ["[root]"]
      when :dir
        [root_link, @path.to_s + "/"]
      else
        dir_title = h(@path.dirname.to_s + "/")
        dir_link = link(dir_title, view: @view, path: @path.dirname)
        [root_link, dir_link, @path.basename.to_s]
      end.join(h(" > "))

      # filter
      unless @path != CWD && Concov::Config.custom_query.empty?
        @filter = []
        Concov::Config.custom_query.each do |title, query|
          selected = [:adapter, :ext, :incl, :excl].all? do |k|
            request[k].to_s == query[k].to_s
          end
          @filter << [uri(query.merge(no_opt: true)), title, selected]
        end
        @filter.unshift(["", "(custom)", true]) if @filter.all? {|a| !a.last }
      end

      # quick chart
      first_day = @view.first_day
      chart = build_timeline_chart(
        @history,
        first_day << 2,
        first_day >> 1,
        @view,
        class: "quick-chart",
        size: "300x100",
        split: 3,
      )
      @chart = link(chart, view: @view.to_chart_view)

      # tabs
      @tabs = [
        [view_icon(:day)     + "day"    , @view.to_day_view],
        [view_icon(:week)    + "week"   , @view.to_week_view],
        [view_icon(:diff)    + "diff"   , @view.to_diff_view],
        [view_icon(:changes) + "changes", @view.to_changes_view],
        [view_icon(:chart)   + "chart"  , @view.to_chart_view],
      ].map do |title, view|
        klass = case
        when view.class == @view.class                   then :selected
        when view.is_a?(WeekView) && @path_type == :file then :disabled
        end
        klass ? %(<span class="#{ klass }">#{ title }</span>)
              : link(title, view: view)
      end
    end


    ##
    ##  directory mode
    ##

    def view_dir
      # dates in view range
      dates = @view.to_dates.to_a

      total_covs = dates.map { [0, 0] }
      @columns = []

      # enumerate columns
      Coverage.list(@path, dates, @opt) do |path, hash|
        # coverage rows
        covs = dates.map {|date| hash[date] || [0, 0] }
        cmps = make_comparison_marks(covs)

        # sum total coverages
        total_covs = total_covs.zip(covs).map do |a|
          a.transpose.map {|n| n.inject(&:+) }
        end

        @columns << [[path.to_s, @path + path], covs.zip(cmps)]
      end

      # total row
      @columns << [nil, total_covs.zip(make_comparison_marks(total_covs))]

      # diff views for each pair of coverages
      @cmp_views =
        dates.each_cons(2).map {|date1, date2| DiffView.new(date1, date2) }
    end

    def make_comparison_marks(covs)
      # score of each coverage
      scores = covs.map do |hit, found|
        Rational(hit, found) if found && found > 0
      end

      # comparison marks for each pair of coverages
      scores.each_cons(2).map do |cov1, cov2|
        case
        when !cov1 || !cov2 then ""
        when cov1 > cov2    then h(">")
        when cov1 < cov2    then h("<")
        else                     h("=")
        end
        end
    end


    ##
    ##  file mode
    ##

    def view_file
      Concov.error("cannot view file in week view") if @view.is_a?(WeekView)

      # hunk generator
      snip = Snipper.new(3) do |snip|
        Coverage.code(@path, *@view) do |column, output|
          snip.add(column, output)
        end
      end

      # handle special request for fragment
      if request.xhr?
        id = h(request["snip"])

        # get n-th hunk
        hunk = snip.nth_hunk(id.to_i)

        # generate html table fragment
        html = ""
        hunk.each do |lineno, *lines|
          html << %(<tr class="snip-#{ id }">)
          html << %(<td class="snip-lineno">#{ lineno }</td>)
          lines.each_slice(2) {|count, line| html << code_markup(count, line) }
          html << %(</tr>)
        end

        # return html (without layout)
        respond(html)
      end

      # all hunks
      @hunks = []
      snip_id = "snip-0"
      snip.each_hunk do |output, hunk|
        @hunks << [output, output ? hunk : [snip_id.dup, hunk.size]]
        snip_id.succ!
      end
    end


    ##
    ##  changes mode
    ##

    def view_changes
      columns = Coverage.changes(8, @path_type, @path, @view.date, @opt)

      @columns = columns.map do |type, *args|
        case type
        when :entry
          date1, date2, hit, found, mark = *args
          title = date2 ? date1.to_show_until(date2 - 1) : date1.to_show + " -"
          current =  date1 <= @view.date && (!date2 || @view.date < date2)
          changes_view = ChangesView.new(date1)
          day_view = DayView.new(date1)
          [:entry, title, current, changes_view, day_view, hit, found, mark]

        when :diff
          date1, date2, change = *args
          title = ["&uarr;"]
          if @path_type != :file
            title << changes_detail(:dir, :added   , change[:created])
            title << changes_detail(:dir, :deleted , change[:deleted])
            title << changes_detail(:dir, :modified, change[:modified])
          else
            title << changes_detail(:file, :added   , change[:code_inc])
            title << changes_detail(:file, :deleted , change[:code_dec])
          end
          title = title.compact.join(" ")
          diff_view = DiffView.new(date1, date2)
          [:diff, title, diff_view, change[:cov_inc], change[:cov_dec]]

        when :navi
          side, date = *args
          date ||= side == :newer ? @last_date : @first_date
          [:navi, side, changes_navi_icon(side), ChangesView.new(date)]
        end
      end
    end

    def changes_detail(type, event, count)
      return if count == 0
      title = "#{ count } #{ type }#{ "s" if count >= 2 } #{ event }"
      mark = changes_detail_icon(type, event, title)
      %(<span title="#{ title }">#{ mark }</span>)
    end

    ##
    ##  chart mode
    ##

    def view_chart
      first_day = @view.first_day
      week = ((first_day >> 1) - first_day).quo(7)
      @charts = [
        [first_day     , first_day >> 1, "month"    , week],
        [first_day << 1, first_day >> 2, "quarter"  , 3],
        [first_day << 3, first_day >> 3, "half year", 6],
      ].map do |first, last, title, split|
        build_timeline_chart(
          @history,
          first,
          last,
          @view,
          class: "chart",
          size: "500x300",
          title: title,
          split: split,
        )
      end
    end


    ##
    ##  miscellaneous
    ##

    # uri maker
    def uri(opt)
      # ramaze base uri
      uri = route_location(self).squeeze("/")

      # setup target location (inherit current location unless specified)
      opt = opt.dup
      path = opt.delete(:path) || @path
      view = opt.delete(:view) || @view
      no_opt = opt.delete(:no_opt)
      unless no_opt
        @opt.each {|k, v| opt[k] = v.is_a?(Array) ? v.join(",") : v }
      end

      # concatenate view
      unless path == CWD && opt.empty? && view == DayView.new(@last_date)
        uri << view.to_path << "/"
      end

      # concatenate path
      uri << path.to_s unless path == CWD

      # concatenate filtering condition
      unless opt.empty?
        query = opt.map {|a| a.map {|s| Rack::Utils.escape(s) }.join("=") }
        uri << "?" << query.join("&")
      end

      uri
    end

    # original anchor maker (Innate::Helper::Link is too rigid and too slow...)
    def link(title, opt)
      klass = %( class="#{ opt.delete(:class) }") if opt.key?(:class)
      %(<a href="#{ h(uri(opt)) }"#{ klass }>#{ title }</a>)
    end
  end
end
