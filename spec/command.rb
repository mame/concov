#
# concov - continuous coverage manager
#
#   * spec/command.rb: command spec
#

require "ramaze"
require "ramaze/spec/bacon"
require "tmpdir"

require "spec/helper"

require "lib/config"
require "lib/error"
require "model/coverage"
require "lib/command"
require "lib/command/init"
require "lib/command/info"
require "lib/command/register"
require "lib/command/view"

# sandbox setup
sandbox_base_path, sandbox_conf_path = setup_sandbox
Dir.chdir(sandbox_base_path)


describe Concov::Command do
  describe "error test" do
    should "report error against no subcommand" do
      run_concov.should ==
        "error: subcommand required; see help for usage.\n"
    end

    should "report error against unknown subcommand" do
      run_concov("unknownfoobarbazqux").should ==
        "error: unknown command: 'unknownfoobarbazqux'\n"
    end

    should "report error against unknown type of information" do
      run_concov("info", "unknownfoobarbazqux").should ==
        "error: unknown information: unknownfoobarbazqux\n"
    end
  end

  describe "initialization" do
    should "fail to access database before initialization" do
      run_concov("info", "initialized?").should == "false\n"
    end

    should "initialize database" do
      run_concov("init").should.be.empty?
      run_concov("info", "initialized?").should == "true\n"
      run_concov("info", "first-date").should.be.empty?
    end

    should "fail to re-initialize database" do
      run_concov("init").should == "error: already initialized\n"
    end
  end

  describe "1st day" do
    should "register tree" do
      expect = [
        /^$/,
        /^gather source code... 1\s*$/,
        /^gather source code... 2\s*$/,
        /^gather source code... 3\s*$/,
        /^gather source code: \d+\.\d+ sec.\s*$/,
        /^$/,
        /^register to database... 1 \/ 3 \(33%\)\s*$/,
        /^register to database... 2 \/ 3 \(66%\)\s*$/,
        /^register to database... 3 \/ 3 \(100%\)\s*$/,
        /^register to database: \d+\.\d+ sec.\s*$/,
      ]
      run_concov("register", "-d", "20090101", sample_env("20090101"))
      .split(/[\r\n]/).each do |line|
        line.should =~ expect.shift
      end

      run_concov("info", "first-date")          .should == "20090101\n"
      run_concov("info", "last-date")           .should == "20090101\n"
      run_concov("info", "last-registered-date").should == "20090101\n"
    end

    should "view directory list" do
      lines = run_concov("view").lines.to_a
      lines.shift.should == "  date: 2009/01/01\n"
      lines.shift.should == "\n"
      lines.pop.should =~ /^  elipsed time: \d+\.\d sec.$/
      lines.pop.should == "\n"
      lines.join.should == <<-END
  +----+-----+-+-+
  |dirs|  %  | | |
  +----+-----+-+-+
  |bar/|60.0%|3|5|
  |foo/|85.7%|6|7|
  +----+-----+-+-+
      END
    end

    should "view file list" do
      lines = run_concov("view", "foo").lines.to_a
      lines.shift.should == "  date: 2009/01/01\n"
      lines.shift.should == "\n"
      lines.pop.should =~ /^  elipsed time: \d+\.\d sec.$/
      lines.pop.should == "\n"
      lines.join.should == <<-END
  +--------+------+-+-+
  | files  |  %   | | |
  +--------+------+-+-+
  |test1.c |100.0%|2|2|
  |test2.rb| 80.0%|4|5|
  +--------+------+-+-+
      END

      lines = run_concov("view", "foo/test1.c").lines.to_a
      lines.shift.should == "  date: 2009/01/01\n"
      lines.shift.should == "\n"
      lines.pop.should =~ /^  elipsed time: \d+\.\d sec.$/
      lines.pop.should == "\n"
      lines.join.should == <<-END
  +-+-+--------------+
  |1|1|int main() {  |
  |2|1|        foo();|
  |3| |}             |
  +-+-+--------------+
      END
    end

    should "view code" do
      lines = run_concov("view", "foo/test2.rb").lines.to_a
      lines.shift.should == "  date: 2009/01/01\n"
      lines.shift.should == "\n"
      lines.pop.should =~ /^  elipsed time: \d+\.\d sec.$/
      lines.pop.should == "\n"
      lines.join.should == <<-END
  +-+-+----------+
  |1|1|5.times do|
  |2|5|  p :foo  |
  |3| |end       |
  |4|1|if false  |
  |5|0|  p :bar  |
  |6| |end       |
  |7|1|p :end    |
  +-+-+----------+
      END

      lines = run_concov("view", "bar/test3.y").lines.to_a
      lines.shift.should == "  date: 2009/01/01\n"
      lines.shift.should == "\n"
      lines.pop.should =~ /^  elipsed time: \d+\.\d sec.$/
      lines.pop.should == "\n"
      lines.join.should == <<-END
  +-+---+------+
  |1|  1|foo   |
  |2| 10|bar   |
  |3|  0|baz   |
  |4|   |qux   |
  |5|100|corge |
  |6|  0|grault|
  +-+---+------+
      END
    end

    should "report error about view" do
      run_concov("view", "baz").should == "error: unknown path\n"

      run_concov("view", "foo", "bar").should ==
      "error: wrong number of arguments; see help for usage\n"
    end

    should "handle week view" do
      lines = run_concov("view", "-d", "w20090101").lines.to_a
      lines.shift.should == "  date: 2008/12/26 - 2009/01/01\n"
      lines.shift.should == "\n"
      lines.pop.should =~ /^  elipsed time: \d+\.\d sec.$/
      lines.pop.should == "\n"
      lines.join.should == <<-END
  +----+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+-----+-+-+
  |dirs| % |   |   | % |   |   | % |   |   | % |   |   | % |   |   | % |   |   |  %  | | |
  +----+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+-----+-+-+
  |bar/|N/A|N/A|N/A|N/A|N/A|N/A|N/A|N/A|N/A|N/A|N/A|N/A|N/A|N/A|N/A|N/A|N/A|N/A|60.0%|3|5|
  |foo/|N/A|N/A|N/A|N/A|N/A|N/A|N/A|N/A|N/A|N/A|N/A|N/A|N/A|N/A|N/A|N/A|N/A|N/A|85.7%|6|7|
  +----+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+-----+-+-+
      END

      run_concov("view", "-d", "w20090101", "foo/test1.c").should ==
        "error: cannot view file in week view\n"
    end

    should "handle diff view" do
      lines = run_concov("view", "-d", "d20090101").lines.to_a
      lines.shift.should == "  date: 2009/01/01 (cf. 2008/12/31)\n"
      lines.shift.should == "\n"
      lines.pop.should =~ /^  elipsed time: \d+\.\d sec.$/
      lines.pop.should == "\n"
      lines.join.should == <<-END
  +----+---+---+---+-----+-+-+
  |dirs| % |   |   |  %  | | |
  +----+---+---+---+-----+-+-+
  |bar/|N/A|N/A|N/A|60.0%|3|5|
  |foo/|N/A|N/A|N/A|85.7%|6|7|
  +----+---+---+---+-----+-+-+
      END

      run_concov("view", "-d", "d20090101", "foo/test1.c").should ==
        "error: invalid date\n"
    end

    should "handle changes view" do
      lines = run_concov("view", "-d", "c20090101").lines.to_a
      lines.shift.should == "  date: 2009/01/01\n"
      lines.shift.should == "\n"
      lines.pop.should =~ /^  elipsed time: \d+\.\d sec.$/
      lines.pop.should == "\n"
      lines.join.should == <<-END
  2009/01/01 - (latest)  (75.0%; 9/12)
      END
    end

    should "handle chart view" do
      run_concov("view", "-d", "g20090101").should ==
        "error: chart mode cannot be used in command-line interface\n"
    end
  end

  describe "2nd day" do
    should "report error" do
      run_concov("register", "-d", "20090101", sample_env("20090102")).should ==
        "error: date must be newer than last date\n"
    end

    should "register tree" do
      expect = [
        /^$/,
        /^gather source code... 1\s*$/,
        /^gather source code... 2\s*$/,
        /^gather source code... 3\s*$/,
        /^gather source code: \d+\.\d+ sec.\s*$/,
        /^$/,
        /^register to database... 1 \/ 3 \(33%\)\s*$/,
        /^register to database... 2 \/ 3 \(66%\)\s*$/,
        /^register to database... 3 \/ 3 \(100%\)\s*$/,
        /^register to database: \d+\.\d+ sec.\s*$/,
      ]
      run_concov("register", "-d", "20090102", sample_env("20090102"))
      .split(/[\r\n]/).each do |line|
        line.should =~ expect.shift
      end

      run_concov("info", "first-date")          .should == "20090101\n"
      run_concov("info", "last-date")           .should == "20090102\n"
      run_concov("info", "last-registered-date").should == "20090102\n"
    end

    should "handle week view" do
      lines = run_concov("view", "-d", "w20090102").lines.to_a
      lines.shift.should == "  date: 2008/12/27 - 2009/01/02\n"
      lines.shift.should == "\n"
      lines.pop.should =~ /^  elipsed time: \d+\.\d sec.$/
      lines.pop.should == "\n"
      lines.join.should == <<-END
  +----+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+-----+-+-+------+-+-+
  |dirs| % |   |   | % |   |   | % |   |   | % |   |   | % |   |   |  %  | | |  %   | | |
  +----+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+-----+-+-+------+-+-+
  |bar/|N/A|N/A|N/A|N/A|N/A|N/A|N/A|N/A|N/A|N/A|N/A|N/A|N/A|N/A|N/A|60.0%|3|5| 60.0%|3|5|
  |foo/|N/A|N/A|N/A|N/A|N/A|N/A|N/A|N/A|N/A|N/A|N/A|N/A|N/A|N/A|N/A|85.7%|6|7|100.0%|9|9|
  +----+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+-----+-+-+------+-+-+
      END
    end

    should "handle diff view" do
      lines = run_concov("view", "-d", "d20090102").lines.to_a
      lines.shift.should == "  date: 2009/01/02 (cf. 2009/01/01)\n"
      lines.shift.should == "\n"
      lines.pop.should =~ /^  elipsed time: \d+\.\d sec.$/
      lines.pop.should == "\n"
      lines.join.should == <<-END
  +----+-----+-+-+------+-+-+
  |dirs|  %  | | |  %   | | |
  +----+-----+-+-+------+-+-+
  |bar/|60.0%|3|5| 60.0%|3|5|
  |foo/|85.7%|6|7|100.0%|9|9|
  +----+-----+-+-+------+-+-+
      END

      lines = run_concov("view", "-d", "d20090102", "foo/test1.c").lines.to_a
      lines.shift.should == "  date: 2009/01/02 (cf. 2009/01/01)\n"
      lines.shift.should == "\n"
      lines.pop.should =~ /^  elipsed time: \d+\.\d sec.$/
      lines.pop.should == "\n"
      lines.join.should == <<-END
  +-+-+--------------+-+--------------+
  |1|1|int main() {  |1|int main() {  |
  |2|1|        foo();|1|        foo();|
  |3| |              |1|  bar();      |
  |4| |              |1|  baz();      |
  |5| |}             | |}             |
  +-+-+--------------+-+--------------+
      END
    end

    should "handle changes view" do
      lines = run_concov("view", "-d", "c20090102").lines.to_a
      lines.shift.should == "  date: 2009/01/02\n"
      lines.shift.should == "\n"
      lines.pop.should =~ /^  elipsed time: \d+\.\d sec.$/
      lines.pop.should == "\n"
      lines.join.should == <<-END
  2009/01/02 - (latest)  (85.7%; 12/14)
    ^
    | 2 files modified
    |
  2009/01/01 (earliest)  (75.0%; 9/12)
      END

      lines = run_concov("view", "-d", "c20090102", "foo/test1.c").lines.to_a
      lines.shift.should == "  date: 2009/01/02\n"
      lines.shift.should == "\n"
      lines.pop.should =~ /^  elipsed time: \d+\.\d sec.$/
      lines.pop.should == "\n"
      lines.join.should == <<-END
  2009/01/02 - (latest)  (100.0%; 4/4)
    ^
    | 2 lines added
    |
  2009/01/01 (earliest)  (100.0%; 2/2)
      END
    end

    # test, test, test...
  end
end
