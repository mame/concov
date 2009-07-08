#
# concov - continuous coverage manager
#
#   * model/files.rb: database of file entries (backend: sequel)
#

require_relative "query"

module Concov
  module Coverage
    class Files < Sequel::Model(:files)
      extend Query

      ##
      ## search methods
      ##

      # whether the path exists at the date
      def self.exist?(path, opt)
        !q(opt, path: path).empty?
      end

      # yields file list of specified path
      def self.list(dir, dates, opt)
        q(opt, date: dates, dir: dir)
        .select(LIST_INFO)
        .order(:file, :date)
        .each do |h|
          yield(Pathname(h.file), h.date, h.hit, h.found)
        end
      end
      LIST_INFO = {
        :date  => :date,
        :file  => :file,
        :hit   => :hit,
        :found => :found
      }

      # returns coverage transition
      def self.history(path, dates, opt)
        hash = {}
        q(opt, date: dates, path: path)
        .select(HISTORY_INFO)
        .order(:date)
        .each do |h|
          hash[h.date] = [h.hit, h.found]
        end
        hash
      end
      HISTORY_INFO = {
        :date  => :date,
        :hit   => :hit,
        :found => :found,
      }

      # yields code and coverage changes of source code
      def self.changes(win, path, date, opt)
        # find all change-marked dates
        changed_dates =
          q(opt, path: path, changed_only: true, include_deleted_files: true)
          .select(:date).distinct.order(:date)

        # count of changed dates
        count = changed_dates.count

        # find index of changed date that corresponds to the specified date
        idx = changed_dates.where(DATE_ID > date).count

        # count of later days than the specified date (one more later day is
        # needed for getting the range end of the first entry when the first
        # entry is the latest one)
        lwin = win + (idx < win + 1 ? 0 : 1)

        # determine window size
        window = win + 1 + lwin

        # clamp the index
        idx = [[idx - lwin, count - window].min, 0].max

        # find all changes
        q = q(opt, path: path, changed_only: true, include_deleted_files: true)
        .left_outer_join(:changes, id: :change)
        .select(CHANGES_INFO)
        .order(:date).reverse

        # clip the changes in the page
        list = q.limit(window, idx).map do |h|
          [h.date, h.hit, h.found, Changes.extract(h)]
        end
        
        # dates for the newer and older pages
        q = q.select(:date)
        newer = q.limit(1, [idx          - (win - 1), 0        ].max)
        older = q.limit(1, [idx + window + (win - 1), count - 1].min)

        [list, newer.single_value, older.single_value]
      end
      DATE_ID = :date.identifier
      CHANGES_INFO = {
        :date      => :date,
        :hit       => :hit,
        :found     => :found,
        :changed   => :changed,
        :modified  => :modified,
        :created   => :created,
        :deleted   => :deleted,
        :code_inc  => :code_inc,
        :code_dec  => :code_dec,
        :cov_inc   => :cov_inc,
        :cov_dec   => :cov_dec,
      }

      # returns coverage of each line of source code
      def self.coverage(path, dates)
        cov = q(date: dates, path: path).select(:coverage).single_value
        coverage_load(cov)
      end

      # yields all directories and their sums of coverage
      def self.summary(date)
        q(date: date, include_deleted_files: true)
        .left_outer_join(:changes, id: :change)
        .group(:dir, :adapter, :ext)
        .select(SUMMARY_INFO)
        .each do |h|
          yield(h, Changes.extract(h))
        end
      end
      SUMMARY_INFO = {
        :date                  => :date,
        :dir                   => :dir,
        :ext                   => :ext,
        :adapter               => :adapter,
        sql_sum(:changed)      => :changed,
        sql_sum(:modified)     => :modified,
        sql_sum(:created)      => :created,
        sql_sum(:deleted)      => :deleted,
        sql_sum(:hit)          => :hit,
        sql_sum(:found)        => :found,
        sql_sum(:code_inc)     => :code_inc,
        sql_sum(:code_dec)     => :code_dec,
        sql_sum(:cov_inc)      => :cov_inc,
        sql_sum(:cov_dec)      => :cov_dec,
      }


      ##
      ##  manipulating methods
      ##

      # add a file that is not modified
      def self.add(date, path, adapter, cov, change = nil)
        # get adapter of previous day (for deleted files)
        adapter ||= q(path: path).select(:adapter).order(:date).last.adapter

        # compare with previous day
        change = detect_change(path, cov, change)

        # store change to the changes database
        if change
          change.save
          change = change.id
        end

        # aggregate coverage
        hit, found = aggregate_coverage(cov) if cov

        # register a new entry
        create(
          date:      date,
          dir:       path.dirname.to_s + "/",
          file:      path.basename.to_s,
          ext:       path.extname.to_s[1..-1],
          adapter:   adapter,
          coverage:  coverage_dump(cov),
          hit:       hit,
          found:     found,
          change:    change,
        )
      end


      ##
      ##  helper methods
      ##

      private

      # calculate hit and found from coverage
      def self.aggregate_coverage(cov)
        found = hit = 0
        cov.each do |cov, line|
          hit   += 1 if cov && cov > 0
          found += 1 if cov
        end
        [hit, found]
      end
      private_class_method :aggregate_coverage

      # calculate code and coverage changes between previous day and today
      def self.detect_change(path, curr_cov, mode = nil)
        # get coverage data of previous day
        prev =
          q(path: path, include_deleted_files: true)
          .select(PREV_INFO)
          .order(:date)
          .last

        # coverage zooms up if there is no prev (or prev is a deleted entry)
        if !prev || !prev.coverage
          return Changes.make(
            type:      :created,
            code_inc:  curr_cov.size,
            cov_inc:   aggregate_coverage(curr_cov).first,
          )
        end

        # convert coverage of previous day
        prev_cov = coverage_load(prev.coverage)

        # coverage zooms down to 0 if this file is deleted
        if mode == :deleted
          return Changes.make(
            type:      :deleted,
            code_dec:  prev_cov.size,
            cov_dec:   aggregate_coverage(prev_cov).first,
          )
        end

        # calculate change
        #   code_inc: number of lines newly added
        #   code_dec: number of lines deleted
        #   cov_inc : number of lines newly covered
        #   cov_dec : number of lines no longer covered
        code_inc = code_dec = cov_inc = cov_dec = 0
        lineno1 = lineno2 = 0

        if mode == :modified
          # this file is modified, so it is needed to examine both code and
          # coverage differences by comparing the index and the HEAD
          Source.changes(path, prev.date) do |action|
            c1 = prev_cov[lineno1] ? prev_cov[lineno1] > 0 : nil
            c2 = curr_cov[lineno2] ? curr_cov[lineno2] > 0 : nil
            case action
            when ?+  then code_inc += 1; cov_inc += 1 if c2; lineno1 -= 1
            when ?-  then code_dec += 1; cov_dec += 1 if c1; lineno2 -= 1
            when ?\s then cov_inc += 1 if !c1 && c2; cov_dec += 1 if c1 && !c2
            end
            lineno1 += 1; lineno2 += 1
          end
        else
          # this file is not modified, so it is enough to count coverage
          # difference only
          prev_cov.zip(curr_cov) do |c1, c2|
            c1 = c1 ? c1 > 0 : nil
            c2 = c2 ? c2 > 0 : nil
            cov_inc += 1 if !c1 && c2; cov_dec += 1 if c1 && !c2
          end
        end

        # make change if there is any change in either code or coverage
        if code_inc > 0 || code_dec > 0 || cov_inc > 0 || cov_dec > 0
          return Changes.make(
            type:      code_inc > 0 || code_dec > 0 ? :modified : :changed,
            code_inc:  code_inc,
            code_dec:  code_dec,
            cov_inc:   cov_inc,
            cov_dec:   cov_dec,
          )
        end

        # no change detected
        nil
      end
      PREV_INFO = {
        :date     => :date,
        :coverage => :coverage,
      }
      private_class_method :detect_change

      # convert coverage array into blob
      def self.coverage_dump(cov)
        cov ? Zlib::Deflate.deflate(Marshal.dump(cov)).to_sequel_blob : nil
      end
      private_class_method :coverage_dump

      # convert blob into coverage array
      def self.coverage_load(cov)
        cov ? Marshal.load(Zlib::Inflate.inflate(cov)) : nil
      end
      private_class_method :coverage_load
    end
  end
end
