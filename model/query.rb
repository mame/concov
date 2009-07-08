#
# concov - continuous coverage manager
#
#   * model/query.rb: query generator
#

module Concov
  module Coverage
    module Query
      CWD = Pathname(".")

      ##
      ##  query generator
      ##

      def q(opt = {}, h)
        h = h.dup

        # split path to dirname and basename
        if h[:path]
          path = h.delete(:path)
          h[:dir], h[:file] = path.dirname, path.basename if path != CWD
        end

        # convert type of dir and file
        h[:dir ] = h[:dir ].cleanpath.to_s + "/" if h[:dir ].is_a?(Pathname)
        h[:file] = h[:file].cleanpath.to_s       if h[:file].is_a?(Pathname)
        h.delete(:dir) if h[:dir] == "./"

        include_deleted_files = h.delete(:include_deleted_files)

        # set filter condition (adapter and ext)
        h[:adapter] = opt[:adapter] if opt[:adapter]
        h[:ext]     = opt[:ext]     if opt[:ext]

        # conjunction
        a = []

        # change mark entry only
        a << ~{ change: nil } if h.delete(:changed_only)

        # set filter condition (incl and excl)
        a <<  dir_pattern(opt[:incl]) if opt[:incl]
        a << ~dir_pattern(opt[:excl]) if opt[:excl]

        # remove deleted files
        a << ~{ hit: nil } unless include_deleted_files

        a << h unless h.empty?

        # integrate conjunction conditions
        cond = a.inject(&:&)

        cond == nil ? self : where(cond)
      end

      def dir_pattern(patterns)
        patterns.split(",").map {|like| :dir.like(like) }.inject(&:|)
      end


      ##
      ##  sql helper methods
      ##

      def sql_sum(s)
        CACHE_SUM[s] ||= :SUM.sql_function(s)
      end
      CACHE_SUM = {}
    end
  end
end
