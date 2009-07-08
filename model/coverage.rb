#
# concov - continuous coverage manager
#
#   * model/coverage.rb: interface of concov database
#

require "sequel"
require "zlib"

require "lib/git"
require "lib/date"

require "model/migrations"
module Concov
  module Coverage
    { :Files       => "files",
      :Directories => "directories",
      :Changes     => "changes",
      :Lock        => "lock",
      :Source      => "source",
    }.each do |const, path|
      autoload(const, File.expand_path(path, File.dirname(__FILE__)))
    end
  end
end

# database interface
module Concov
  module Coverage
    CWD = Pathname(".")

    ##
    ##  search methods
    ##

    # yield coverage list of specified path
    def self.list(path, dates, opt, &blk)
      model, args = path == CWD ? [Directories, []] : [Files, [path]]

      prev_path, hash = nil, {}
      model.list(*args, dates, opt) do |path, date, hit, found|
        # merge information about identical paths but different dates
        if prev_path && prev_path != path
          yield(prev_path, hash)
          hash = {}
        end
        prev_path, hash[date] = path, [hit, found]
      end
      yield(prev_path, hash) if !hash.empty?
    end

    # return path type
    #   :top  => list of all directories (path == CWD)
    #   :dir  => file list of the directory specified by path
    #   :file => content of the file specified by path
    def self.path_type(path, opt)
      case
      when path == CWD                   then :top
      when Directories.exist?(path, opt) then :dir
      when Files.exist?(path, opt)       then :file
      end
    end

    # return first date of source code revision
    def self.first_date(opt = {})
      Directories.first_date(opt)
    end

    # return last date of source code revision
    def self.last_date(opt = {})
      Directories.last_date(opt)
    end

    # return last registered date
    def self.last_registered_date
      Directories.last_registered_date
    end

    # return coverage transition
    def self.history(path_type, path, dates, opt)
      (path_type != :file ? Directories : Files).history(path, dates, opt)
    end

    # return coverage of each line of source code
    def self.coverage(path, date)
      Files.coverage(path, date)
    end

    # yield view or diff of source code
    def self.code(path, date1, date2 = nil)
      unless date2
        cov = Coverage.coverage(path, date1) || []

        Coverage.view_file(path, date1) do |line, lno|
          count = cov[lno]
          yield([lno + 1, count, line.chomp], count)
        end
      else
        cov1 = Coverage.coverage(path, date1) || []
        cov2 = Coverage.coverage(path, date2) || []

        # Todo: XXX: test dates not registered!!!
        Coverage.diff_file(path, date1, date2) do |action, line, lno1, lno2|

          # kind of action:
          #   :add : line is added; line belongs to right row only
          #   :del : line is deleted; line belongs to left row only
          #   nil  : common line; line belongs to both rows
          #
          # line: text of code fragment
          # lno1: line number of left row
          # lno2: line number of right row
          count1, count2 = cov1[lno1], cov2[lno2]
          line = line.chomp

          column = [
            action != :del ? lno2 + 1 : nil,
            *(action != :add ? [count1, line] : [nil, nil]),
            *(action != :del ? [count2, line] : [nil, nil]),
          ]

          coverage1 = count1 && count1 > 0 ? :covered : count1
          coverage2 = count2 && count2 > 0 ? :covered : count2

          yield(column, coverage1 != coverage2 || action != nil)
        end
      end
    end

    # yield view of source code
    def self.view_file(path, date)
      lineno = 0
      Source.view_file(path, date) do |line|
        yield(line, lineno)
        lineno += 1
      end
    end

    # yield diff of source code
    def self.diff_file(path, date1, date2)
      lineno1 = lineno2 = 0
      Source.diff_file(path, date1, date2) do |action, line|
        action = ACTION[action]
        yield(action, line, lineno1, lineno2)
        lineno1 += 1 if action != :add
        lineno2 += 1 if action != :del
      end
    rescue Git::GitError
    end
    ACTION = { ?+ => :add, ?- => :del }

    # yield changes of source code
    def self.changes(win, path_type, path, date, opt)
      model = path_type != :file ? Directories : Files

      # enumerate changed dates
      list, newer, older = model.changes(win, path, date, opt)

      # rearrenge data (set previous date and shift change)
      prev_date = prev_change = nil
      list = list.map do |date, hit, found, change|
        entry = [date, prev_date, hit, found, prev_change]
        prev_date, prev_change = date, change.values.dup
        entry
      end

      # remove first entry if it is extra
      if list.size > win * 2 + 1
        list.shift
        list.first[-1] = nil
      end

      # delete dates for newer and older page if the page is the same as the
      # current one
      newer = nil if list.first.first == newer
      older = nil if list.last .first == older

      # prepare to format
      list = list.each.with_object([]) do |(*dates, hit, found, change), list|
        list << [:diff, *dates, change] if change
        list << [:entry, *dates, hit, found]
      end

      # add either navigation to newer and older page or edge mark
      newer ? list.unshift([:navi, :newer, newer]) : list.first << :latest
      older ? list.push(   [:navi, :older, older]) : list.last  << :earliest

      list
    end

    # yield backend names
    def self.acknowledge
      yield "sequel " + Sequel::VERSION
      yield "git " + Source.version
    end


    ##
    ##  manipulating methods
    ##

    # initialize database
    def self.init
      CreateDatabase.apply(DB, :up)
      Source.init
    end

    def self.initialized?
      DB.table_exists?(:lock)
    end

    # commit new tree
    def self.register(date, progress)
      transaction do
        # check date
        last_date = self.last_registered_date
        if last_date && last_date >= date
          Concov.error("date must be newer than last date")
        end

        # setup for registering new tree
        Source.clear_tree

        # if unregistered date if found,
        if last_date && last_date + 1 < date
          # once, all entries are deleted
          modified_files = Coverage::Source.modified_files(last_date)
          unless modified_files.empty?
            last_date += 1
            modified_files.each_key do |path|
              Files.add(last_date, path, nil, nil, :deleted)
            end
            Directories.build_index(last_date)
            Source.commit(last_date)
          end

          # then, new tree will be registered
        end

        # yield proc to create new file of source code, and get coverages
        idx = 0
        new_file = ->(path) do
          progress["gather source code", idx += 1]
          Source.new_file(path)
        end
        covs = yield(new_file)

        # cancel empty file
        covs.each do |path, (adapter, cov)|
          if cov.compact.empty?
            covs.delete(path)
            Source.cancel_file(path)
          end
        end

        if covs.empty?
          msg = "nothing to register found; empty tree will be registered"
          progress["warning: " + msg]
        end

        # add remained files to the index
        Source.add unless covs.empty?

        # check modified files by comparing HEAD and the index
        # (note: both modified files and deleted files are included)
        if last_date
          modified_files = Coverage::Source.modified_files(last_date)
        end

        # register captured files
        covs.each_with_index do |(path, (adapter, cov)), i|

          if !last_date || modified_files.delete(path)
            # this file is modified, so the difference will be examined
            # carefully since its number of `found' may be changed

            Files.add(date, path, adapter, cov, :modified)
          else
            # this file is not modified

            Files.add(date, path, adapter, cov)
          end

          # progress report
          progress["register to database", i + 1, covs.size]
        end

        if modified_files
          # remained files are all deleted files
          modified_files.each_key do |path|
            Files.add(date, path, nil, nil, :deleted)
          end
        end

        # build directory index by summarizing Files database
        Directories.build_index(date)

        # commit the index to the repository
        Source.commit(date)
      end
    end

    # lock database
    def self.transaction
      DB.transaction do
        Lock.synchronize { yield }
      end
    end

    # (re)connect database specified by the configuration
    def self.deploy
      if defined?(DB)
        DB.disconnect
        remove_const(:DB)
      end

      Config.database_path.mkpath
      path = Config.database_path + "coverage.db"
      const_set(:DB, Sequel.connect("amalgalite://" + path.to_s))

      Files.db = DB
      Directories.db = DB
      Changes.db = DB
      Lock.db = DB
      Source.deploy
    end
  end
end
