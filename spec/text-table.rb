#
# concov - continuous coverage manager
#
#   * spec/text-table.rb: text-table spec
#

require "ramaze"
require "ramaze/spec/bacon"

require "lib/text-table"

describe Concov::TextTable do
  def build(str)
    str.gsub(/^\s*/, "").chomp
  end

  should "run example correctly" do
    Concov::TextTable.build("rl") do |table|
      table << ["foo/bar", "baz/qux"]
      table << [["c", "*"], "@@@"]
      table << nil
      table << [123, 456]
    end.to_s.should == build(<<-END)
      +-------+-------+
      |foo/bar|baz/qux|
      |   *   |@@@    |
      +-------+-------+
      |    123|456    |
      +-------+-------+
    END
  end

  should "return console table" do
    Concov::TextTable.build("ll") do |table|
      table << %w(333 333)
      table << %w(1 55555)
    end.to_s.should == build(<<-END)
      +---+-----+
      |333|333  |
      |1  |55555|
      +---+-----+
    END
  end

  should "handle align" do
    Concov::TextTable.build("lcr") do |table|
      table << %w(333 333 333)
      table << %w(1 1 1)
    end.to_s.should == build(<<-END)
      +---+---+---+
      |333|333|333|
      |1  | 1 |  1|
      +---+---+---+
    END
  end

  should "handle explicit align" do
    Concov::TextTable.build("lcr") do |table|
      table << %w(333 333 333)
      table << %w(1 1 1)
      table << [[?r, 2], [?l, 2], [?c, 2]]
    end.to_s.should == build(<<-END)
      +---+---+---+
      |333|333|333|
      |1  | 1 |  1|
      |  2|2  | 2 |
      +---+---+---+
    END
  end

  should "handle vertical bar" do
    Concov::TextTable.build("ll") do |table|
      table << %w(12 34)
      table << nil
      table << nil
      table << nil
      table << %w(56 78)
    end.to_s.should == build(<<-END)
      +--+--+
      |12|34|
      +--+--+
      +--+--+
      +--+--+
      |56|78|
      +--+--+
    END
  end

  should "handle empty table" do
    Concov::TextTable.build("lll") do |table|
    end.to_s.should == build(<<-END)
      ++
      ++
    END
  end
end
