#
# concov - continuous coverage manager
#
#   * spec/parser.rb: parser spec
#

require "ramaze"
require "ramaze/spec/bacon"

require "pathname"
require "tmpdir"

require "lib/error"
require "lib/parser"
require "lib/parser/gcov"
require "lib/parser/rbcov"

describe Concov::Parser do
  parsers = [Concov::GcovParser, Concov::RbcovParser]

  before do
    @tmpdir = Pathname(Dir.mktmpdir)
  end

  after do
    @tmpdir.rmtree
  end

  should "return supported extensions correctly" do
    Concov::Parser.supported_extensions.should == parsers.map {|k| k::EXT }
  end

  should "parse gcov correctly" do
    path = @tmpdir + "foo" + "foo.gcda##foo.c.gcov"
    path.dirname.mkpath
    open(path, "w") do |f|
      f.puts "        -:    0:Source:foo.c"
      f.puts "        -:    0:Graph:foo.gcno"
      f.puts "        -:    0:Data:foo.gcda"
      f.puts "        -:    0:Run:100"
      f.puts "        -:    0:Programs:1"
      f.puts "        1:    1:int main(void) {"
      f.puts "        1:    2:  int i;"
      f.puts "      301:    3:  for (i = 0; i < 300; i++) {"
      f.puts "      300:    4:    puts(\"foo\");"
      f.puts "        -:    5:  }"
      f.puts "        1:    6:  if (0) {"
      f.puts "    #####:    7:    puts(\"bar\");"
      f.puts "        -:    8:  }"
      f.puts "        1:    9:  return 0;"
      f.puts "        -:   10:}"
    end

    expect = [
      [:path, "foo.c", "gcov"],
      [:line,  1,   1, "int main(void) {"],
      [:line,  2,   1, "  int i;"],
      [:line,  3, 301, "  for (i = 0; i < 300; i++) {"],
      [:line,  4, 300, "    puts(\"foo\");"],
      [:line,  5, nil, "  }"],
      [:line,  6,   1, "  if (0) {"],
      [:line,  7,   0, "    puts(\"bar\");"],
      [:line,  8, nil, "  }"],
      [:line,  9,   1, "  return 0;"],
      [:line, 10, nil, "}"],
    ]
    Concov::Parser.parse(path) do |*a|
      a.should == expect.shift
    end
    expect.should.be.empty?
  end

  should "parse rbcov correctly" do
    path = @tmpdir + "foo" + "foo.rbcov"
    path.dirname.mkpath
    open(path, "w") do |f|
      f.puts "        1:    1:3.times do"
      f.puts "        3:    2:  p :foo"
      f.puts "        -:    3:end"
      f.puts "        -:    4:"
      f.puts "        1:    5:if false"
      f.puts "    #####:    6:  p :bar"
      f.puts "        -:    7:end"
    end

    expect = [
      [:path, "foo.rb", "rbcov"],
      [:line,  1,   1, "3.times do"],
      [:line,  2,   3, "  p :foo"],
      [:line,  3, nil, "end"],
      [:line,  4, nil, ""],
      [:line,  5,   1, "if false"],
      [:line,  6,   0, "  p :bar"],
      [:line,  7, nil, "end"],
    ]
    Concov::Parser.parse(path) do |*a|
      a.should == expect.shift
    end
    expect.should.be.empty?
  end

  should "report error against malformed gcov" do
    path = @tmpdir + "foo" + "foo.gcda##foo.c.gcov"
    path.dirname.mkpath
    open(path, "w") do |f|
      f.puts "        1:    1:int main(void) {"
      f.puts "        1:    2:  int i;"
      f.puts "      301:    3:  for (i = 0; i < 300; i++) {"
      f.puts "      300:    4:    puts(\"foo\");"
      f.puts "        -:    5:  }"
      f.puts "        1:    6:  if (0) {"
      f.puts "    #####:    7:    puts(\"bar\");"
      f.puts "        -:    8:  }"
      f.puts "        1:    9:  return 0;"
      f.puts "        -:   10:}"
    end

    ->{ Concov::Parser.parse(path) { throw :foo } }.should
      .raise(Concov::ConcovError)
  end
end
