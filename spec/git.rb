#
# concov - continuous coverage manager
#
#   * spec/git.rb: git spec
#

require "ramaze"
require "ramaze/spec/bacon"

require "pathname"
require "tmpdir"

require "lib/git"

# setup repository space for testing
$tmpdir = Pathname(Dir.mktmpdir)
at_exit do
  # purge temporal directory
  $tmpdir.rmtree
end

describe Concov::Git do
  def add(file, content)
    $tmpdir.mkpath
    (@work + file).open("w") {|file| file.print(content) }
  end

  def del(file)
    (@work + file).unlink
  end

  before do
    @work = $tmpdir + "work"
    @work.mkpath
    @git = Concov::Git.new($tmpdir + "git", @work)
  end

  should "return version" do
    @git.version.should.be.an.instance_of?(String)
  end

  should "work typical use case" do
    @git.init
    add("foo", "FOO\n")
    @git.add(@work)
    @git.commit("1")
    @git.tag("1")
    @git.cat_file(Pathname("foo"), "1").should == "FOO\n"
  end

  should "work typical use case 2" do
    add("foo", "BAR\n")
    add("bar", "BAZ\n")
    @git.add(@work)
    @git.commit("2")
    @git.tag("2")
    @git.add(@work)
    @git.commit("3")
    @git.tag("3")
    del("foo")
    add("bar", "BAZ\nQUX\n")
    @git.add(@work)
    @git.commit("4")
    @git.tag("4")

    @git.cat_file("foo", "1").should == "FOO\n"
    @git.cat_file("foo", "2").should == "BAR\n"
    @git.cat_file("foo", "3").should == "BAR\n"
    ->{ @git.cat_file("foo", "4") }.should.raise(Concov::Git::GitError)
    ->{ @git.cat_file("bar", "1") }.should.raise(Concov::Git::GitError)
    @git.cat_file("bar", "2").should == "BAZ\n"
    @git.cat_file("bar", "3").should == "BAZ\n"
    @git.cat_file("bar", "4").should == "BAZ\nQUX\n"
    ->{ @git.cat_file("baz/qux", "1") }.should.raise(Concov::Git::GitError)
  end

  should "commit empty file" do
    add("empty", "")
    @git.add(@work)
    @git.commit("5")
    @git.tag("5")

    @git.cat_file("empty", "5").should == ""
  end

  should "reset" do
    add("bar", "123")
    @git.add(@work)
    @git.diff_index(nil, "5").should == "1\t2\tbar\n"
    @git.reset
    @git.diff_index(nil, "5").should == ""
  end

  should "stop iteration" do
    @git.cat_file("bar", "5") do |io|
      io.gets.should == "BAZ\n"
      break
    end
  end

  should "work diff" do
    add("bar", "baz\nQUX\n")
    @git.add(@work)
    @git.diff_index("bar", "5") do |io|
      nil until io.gets.start_with? ?@
      io.gets.should == "-BAZ\n"
      io.gets.should == "+baz\n"
      io.gets.should == " QUX\n"
    end
    @git.diff_tree("bar", "2", "5") do |io|
      nil until io.gets.start_with? ?@
      io.gets.should == " BAZ\n"
      io.gets.should == "+QUX\n"
    end
  end
end
