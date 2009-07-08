#
# concov - continuous coverage manager
#
#   * model/directories.rb: database of directory entries (backend: sequel)
#

#
# Note: this database serves as search index; all information is derived from
# Files database
#
# Note: this is tested with sqlite3 only
#

require_relative "query"

module Concov
  module Coverage
    class Directories < Sequel::Model(:directories)
      extend Query

      ##
      ## search methods
      ##

      # whether the path exists at the date
      def self.exist?(dir, opt)
        !q(opt, dir: dir).empty?
      end

      # yield directory list at specified date
      def self.list(dates, opt)
        q(opt, date: dates)
        .select(LIST_INFO).group(:dir, :date)
        .order(:dir, :date)
        .each do |h|
          yield(Pathname(h.dir), h.date, h.hit.to_i, h.found.to_i)
        end
      end
      LIST_INFO = {
        :date           => :date,
        :dir            => :dir,
        sql_sum(:hit)   => :hit,
        sql_sum(:found) => :found,
      }

      # return coverage transition
      def self.history(dir, dates, opt)
        hash = {}
        q(opt, date: dates, dir: dir)
        .select(HISTORY_INFO).group(:date)
        .order(:date)
        .each do |h|
          hash[h.date] = [h.hit.to_i, h.found.to_i]
        end
        hash
      end
      HISTORY_INFO = {
        :date           => :date,
        sql_sum(:hit)   => :hit,
        sql_sum(:found) => :found,
      }

      # yields code and coverage changes of source code
      def self.changes(win, dir, date, opt)
        # find all change-marked dates
        changed_dates =
          q(opt, dir: dir, changed_only: true, include_deleted_files: true)
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
        q = q(opt, dir: dir, date: changed_dates, include_deleted_files: true)
        .left_outer_join(:changes, id: :change)
        .select(CHANGES_INFO).group(:date)
        .order(:date).reverse

        # clip the changes in the page
        list = q.limit(window, idx).map do |h|
          [h.date, h.hit.to_i, h.found.to_i, Changes.extract(h)]
        end

        # dates for the newer and older pages
        q = q.select(:date)
        newer = q.limit(1, [idx          - (win - 1), 0        ].max)
        older = q.limit(1, [idx + window + (win - 1), count - 1].min)

        [list, newer.single_value, older.single_value]
      end
      DATE_ID = :date.identifier
      CHANGES_INFO = {
        :date               => :date,
        sql_sum(:hit)       => :hit,
        sql_sum(:found)     => :found,
        sql_sum(:changed)   => :changed,
        sql_sum(:modified)  => :modified,
        sql_sum(:created)   => :created,
        sql_sum(:deleted)   => :deleted,
        sql_sum(:code_inc)  => :code_inc,
        sql_sum(:code_dec)  => :code_dec,
        sql_sum(:cov_inc)   => :cov_inc,
        sql_sum(:cov_dec)   => :cov_dec,
      }

      # return first date when any directories is registered
      def self.first_date(opt)
        date = q(opt).select(:date).min(:date)
        date ? Date.parse(date) : nil
      end

      # return last date when any directories is registered
      def self.last_date(opt)
        date = q(opt).select(:date).max(:date)
        date ? Date.parse(date) : nil
      end

      # return last date when any directories is registered (even empty tree
      # will be returned)
      def self.last_registered_date
        date = q({}, include_deleted_files: true).select(:date).max(:date)
        date ? Date.parse(date) : nil
      end


      ##
      ##  manipulating methods
      ##

      # summarize Files database and builds index
      def self.build_index(date)
        Files.summary(date) do |h|
          change = Changes.extract(h)

          # store change to the changes database
          if change
            change.save
            change = change.id
          end

          # make a new entry
          create(
            date:      h.date,
            dir:       h.dir,
            ext:       h.ext,
            adapter:   h.adapter,
            hit:       h.hit,
            found:     h.found,
            change:    change,
          )
        end
      end
    end
  end
end
