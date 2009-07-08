#
# concov - continuous coverage manager
#
#   * spec/snipper.rb: snipper spec
#

require "ramaze"
require "ramaze/spec/bacon"

require "lib/snipper"


describe Concov::Snipper do
  def build(a)
    a.map.with_index {|r, i| [i % 2 == 0, r.to_a] }
  end

  should "run example correctly" do
    s = Concov::Snipper.new(2) do |s|
      (0..20).each {|n| s.add(n, n == 10) }
    end

    s.hunks.should ==
      [[true , [ 0,  1]],
       [false, [ 2,  3,  4,  5,  6,  7]],
       [true , [ 8,  9, 10, 11, 12]],
       [false, [13, 14, 15, 16, 17, 18]],
       [true , [19, 20]]]
  end

  should "show around 15" do
    Concov::Snipper.new(1) {|s| (1..29).each {|x| s.add(x, x == 15) } }.hunks
      .should == build([1..1, 2..13, 14..16, 17..28, 29..29])

    Concov::Snipper.new(2) {|s| (1..29).each {|x| s.add(x, x == 15) } }.hunks
      .should == build([1..2, 3..12, 13..17, 18..27, 28..29])

    Concov::Snipper.new(3) {|s| (1..29).each {|x| s.add(x, x == 15) } }.hunks
      .should == build([1..3, 4..11, 12..18, 19..26, 27..29])
  end

  should "shouw around 10 and 20" do
    Concov::Snipper.new(1) do |s|
      (1..29).each {|x| s.add(x, x == 10 || x == 20) }
    end.hunks.should ==
      build([1..1, 2..8, 9..11, 12..18, 19..21, 22..28, 29..29])

    Concov::Snipper.new(2) do |s|
      (1..29).each {|x| s.add(x, x == 10 || x == 20) }
    end.hunks.should ==
      build([1..2, 3..7, 8..12, 13..17, 18..22, 23..27, 28..29])

    Concov::Snipper.new(3) do |s|
      (1..29).each {|x| s.add(x, x == 10 || x == 20) }
    end.hunks.should == build([1..29])
  end

  should "show only head and tail" do
    [
      [ [*1..1], [1..1] ],
      [ [*1..2], [1..2] ],
      [ [*1..3], [1..3] ],
      [ [*1..4], [1..1, 2..3, 4..4] ],
      [ [*1..5], [1..1, 2..4, 5..5] ],
    ].each do |ary, exp|
      Concov::Snipper.new(1) {|s| ary.each {|x| s.add(x, false) } }.hunks
        .should == build(exp)
    end

    [
      [ [*1..1], [1..1] ],
      [ [*1..2], [1..2] ],
      [ [*1..3], [1..3] ],
      [ [*1..4], [1..4] ],
      [ [*1..5], [1..5] ],
      [ [*1..6], [1..6] ],
      [ [*1..7], [1..2, 3..5, 6..7] ],
      [ [*1..8], [1..2, 3..6, 7..8] ],
    ].each do |ary, exp|
      Concov::Snipper.new(2) {|s| ary.each {|x| s.add(x, false) } }.hunks
        .should == build(exp)
    end
  end

  should "handle empty sequence correctly" do
    Concov::Snipper.new(1) {|s|}.hunks.should == []
    Concov::Snipper.new(2) {|s|}.hunks.should == []
    Concov::Snipper.new(3) {|s|}.hunks.should == []
  end

  should "handle each_hunk" do
    a = []
    Concov::Snipper.new(2) do |s|
      (1..29).each {|x| s.add(x, x == 10 || x == 20) }
    end.each_hunk {|*x| a << x }
    a.should == build([1..2, 3..7, 8..12, 13..17, 18..22, 23..27, 28..29])
  end

  should "stop iteration after nth hunk is found" do
    a = []
    snip = Concov::Snipper.new(2) do |s|
      (1..29).each do |x|
        a << x
        s.add(x, x == 10 || x == 20)
      end
    end
    snip.nth_hunk(0).should == (1..2).to_a
    a.should == (1..7).to_a

    a = []
    snip = Concov::Snipper.new(2) do |s|
      (1..29).each do |x|
        a << x
        s.add(x, x == 10 || x == 20)
      end
    end
    snip.nth_hunk(1).should == (3..7).to_a
    a.should == (1..15).to_a

    a = []
    snip = Concov::Snipper.new(2) do |s|
      (1..29).each do |x|
        a << x
        s.add(x, x == 10 || x == 20)
      end
    end
    snip.nth_hunk(2).should == (8..12).to_a
    a.should == (1..15).to_a
  end
end
