#
# concov - continuous coverage manager
#
#   * model/source.rb: database of source code text (backend: git)
#

module Concov
  module Coverage
    class Source
      # focus on repository specified by the configuration
      def self.deploy
        path = Config.database_path + "source.db"
        @path = path + "work"
        @git = Git.new((path + "git").to_s, @path)
      end

      # initialize repository
      def self.init
        @path.mkpath
        @git.init
      end

      # delete all working tree
      def self.clear_tree
        @git.rm(@path) rescue nil
        @path.rmtree if @path.exist?
        @path.mkpath
      end

      # create new file
      def self.new_file(path)
        (@path + path).dirname.mkpath
        open(@path + path, "wb", :encoding => "ASCII-8BIT")
      end

      # cancel created file
      def self.cancel_file(path)
        (@path + path).delete
      end

      # add all files (in path) to the index
      def self.add
        @git.add(@path)
      end

      # commit the index to the repository
      def self.commit(date)
        tag = date.to_path
        @git.commit(tag)
        @git.tag(tag)
      end

      # yield IO of text of source code
      def self.view_file(path, date, &blk)
        @git.cat_file(path, date.to_path) do |f|
          blk ? f.each_line(&blk) : f.read
        end
      end

      # yield difference of two text of source code
      def self.diff_file(path, date1, date2)
        header = true
        date1, date2 = [date1, date2].map {|date| date.to_path }
        @git.diff_tree(path, date1, date2) do |f|
          while action = f.getc
            if header
              header = false if action == ?@
              f.gets
            else
              yield(action, f.gets)
            end
          end
        end
        if header
          # if there is no difference
          @git.cat_file(path, date2) do |f|
            f.each_line {|line| yield(" ", line) }
          end
        end
      end

      # return list of changed files
      def self.modified_files(date)
        h = {}
        @git.diff_index(nil, date.to_path) do |f|
          f.each_line do |line|
            /^\d+\s+\d+\s+(?<path>.*)$/ =~ line
            h[Pathname(path)] = true
          end
        end
        h
      end

      # detect changes between the index and the repository 
      def self.changes(path, date)
        date = date.to_path
        header = true
        @git.diff_index(path, date) do |f|
          while c = f.getc
            if header
              header = false if c == ?@
              f.gets
            else
              yield(c)
              f.gets
            end
          end
        end
        if header
          # if there is no difference
          @git.cat_file(path, date) do |f|
            f.each_line { yield(" ") }
          end
        end
      end

      # return version information of backend
      def self.version
        @git.version.sub(/^git\s+version\s*/, "").chomp
      end
    end
  end
end
