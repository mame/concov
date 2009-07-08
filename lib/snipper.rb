#
# concov - continuous coverage manager
#
#   * lib/snipper.rb: extract elements from whole sequence by snipping
#
#
# example:
#   # create new snipper whose window size is 2, and pour 0..20 to snipper with
#   # specifying 4 and 11 must be output.
#   s = Snipper.new(2) do |s|
#     (0..20).each {|n| s.add(n, n == 10) }
#   end
#
#   # result consists of pairs of flag, which represents whether this entry is
#   # output, and hunk, which is a subsequence of elements.  2 elements before
#   # and after elements that must be output are included in the same hunk.  In
#   # addition, the head and tail of original sequence are also output hunk.
#   s.hunks  #=> [[true,  [ 0,  1]],                 # output hunk (head)
#                 [false, [ 2,  3,  4,  5,  6,  7]], # snipped hunk
#                 [true,  [ 8,  9, 10, 11, 12]],     # output hunk
#                 [false, [13, 14, 15, 16, 17, 18]], # snipped hunk
#                 [true,  [19, 20]]]                 # output hunk (tail)
#

module Concov
  class Snipper
    # takes a pair of new element and output flag
    def add(line, output)
      if @follow
        @follow = output ? @win - 1 : @follow > 0 ? @follow - 1 : nil
        @view << line
      elsif output
        @view.concat(@buff) << line
        @buff.clear
        @follow = @win - 1
      else
        @buff << line
        if @buff.size > @win * 2 || (@buff.size > @win && !@snip.empty?)
          flush
          @snip.concat(@buff.slice!(0, @buff.size - @win))
        end
      end
    end

    # enumerate all hunks
    def each_hunk(&blk)
      @yield_block = blk
      @gen_block.call(self)
      @view.concat(@buff)
      flush
    end

    # return all hunks as an array
    def hunks
      result = []
      each_hunk {|output, hunk| result << [output, hunk] }
      result
    end

    # return n-th hunk
    def nth_hunk(idx)
      i = 0
      each_hunk do |output, hunk|
        return hunk if i == idx
        i += 1
      end
      nil
    end

    private

    def initialize(win = 3, &blk)
      @win = win
      @buff, @snip, @view = [], [], []
      @follow = win - 1
      @gen_block = blk
    end

    def flush
      unless @view.empty?
        @yield_block[false, @snip] unless @snip.empty?
        @yield_block[true, @view]
        @snip, @view = [], []
      end
    end
  end
end
