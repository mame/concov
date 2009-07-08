#
# concov - continuous coverage manager
#
#   * spec/model.rb: model spec (typical use case only)
#

require "ramaze"
require "ramaze/spec/bacon"
require "tmpdir"

require "spec/helper"

require "lib/config"
require "lib/error"
require "model/coverage"

# sandbox setup
sandbox_base_path, sandbox_conf_path = setup_sandbox

# load configuration file
Concov::Config.deploy(sandbox_conf_path)


# spec helper
def list_check(path, date, opt, paths, hashs)
  paths = paths.map {|path| Pathname(path) }
  Concov::Coverage.list(path, date, opt) do |path, hash|
    path.should == paths.shift
    hash.should == hashs.shift
  end
  paths.should.be.empty?
  hashs.should.be.empty?
end

def code_check(path, date1, date2 = nil, code)
  Concov::Coverage.code(path, date1, date2) do |line|
    line.should == code.shift
  end
  code.should.be.empty?
end

def changes_check(win, path_type, path, date, opt, changes)
  Concov::Coverage.changes(win, path_type, path, date, opt).each do |line|
    line.should == changes.shift
  end
end


describe Concov::Coverage do
  describe "initialization" do
    should "yield acknowledge" do
      Concov::Coverage.acknowledge do |ack|
        ack.should.be.an.instance_of String
      end
    end

    should "fail to access before initialization" do
      ->{ Concov::Coverage.last_date }.should.raise(Exception)
    end

    should "initialize database" do
      Concov::Coverage.init
      Concov::Config.deploy(sandbox_conf_path)
      Concov::Coverage.last_date.should.be.nil
    end

    should "fail to re-initialize database" do
      ->{ Concov::Coverage.init }.should.raise(Exception)
    end
  end

  cwd = Pathname(".")
  day1 = Date.parse("20090101")
  describe "1st day: sample tree with three files" do

    should "success to register" do
      log = []
      prog = ->(*a) { log << a }
      Concov::Coverage.register(day1, prog) do |new_file|
        covs = {}

        #
        # test data 1 (foo/test1.c.gcov)
        #
        #   -:0:Source:foo/test1.c
        #   1:1:int main() {
        #   1:2:  foo();
        #   -:3:}
        #
        path = Pathname("foo/test1.c")
        file = new_file[path]
        file.puts "int main() {"
        file.puts "  foo();"
        file.puts "}"
        file.close
        covs[path] = ["gcov", [1, 1, nil]]

        #
        # test data 2 (foo/test2.rbcov)
        #
        #   1:1:5.times do
        #   5:2:  p :foo
        #   -:3:end
        #   1:4:if false
        #   0:5:  p :bar
        #   -:6:end
        #   1:7:p :end
        #
        path = Pathname("foo/test2.rb")
        file = new_file[path]
        file.puts "5.times do"
        file.puts "  p :foo"
        file.puts "end"
        file.puts "if false"
        file.puts "  p :bar"
        file.puts "end"
        file.puts "p :end"
        file.close
        covs[path] = ["rbcov", [1, 5, nil, 1, 0, nil, 1]]

        #
        # test data 3 (bar/test3.y.gcov)
        #
        #   -:0:Source:bar/test3.y
        #   1:1:foo
        #  10:2:bar
        #   0:3:baz
        #   -:4:qux
        # 100:5:corge
        #   0:6:grault
        #
        path = Pathname("bar/test3.y")
        file = new_file[path]
        file.puts "foo"
        file.puts "bar"
        file.puts "baz"
        file.puts "qux"
        file.puts "corge"
        file.puts "grault"
        file.close
        covs[path] = ["gcov", [1, 10, 0, nil, 100, 0]]
        covs
      end

      log.should == [
        ["gather source code", 1],
        ["gather source code", 2],
        ["gather source code", 3],
        ["register to database", 1, 3],
        ["register to database", 2, 3],
        ["register to database", 3, 3],
      ]
    end

    should "return path_type correctly" do
      Concov::Coverage.path_type(cwd                    , {}).should == :top
      Concov::Coverage.path_type(Pathname("foo/")       , {}).should == :dir
      Concov::Coverage.path_type(Pathname("foo/test1.c"), {}).should == :file
    end

    should "return last_date correctly" do
      Concov::Coverage.last_date.should == day1
    end

    should "return first_date correctly" do
      Concov::Coverage.first_date.should == day1
    end


    #
    # correct result for current state
    #
    #   foo/test1.c : 2 / 2
    #   foo/test2.rb: 4 / 5
    #   bar/test3.y : 3 / 5
    #
    should "return history correctly" do
      range = day1..day1
      Concov::Coverage.history(:top, cwd, range, {})
        .should == { day1 => [9, 12] }

      Concov::Coverage.history(:dir, Pathname("foo/"), range, {})
        .should == { day1 => [6, 7] }

      Concov::Coverage.history(:file, Pathname("foo/test1.c"), range, {})
        .should == { day1 => [2, 2] }
    end

    should "return directory list correctly" do
      list_check(
        cwd, day1, {},
        %w(bar/ foo/),
        [{ day1 => [3, 5] }, { day1 => [6, 7]}]
      )
    end

    should "return directory list with filtering correctly" do
      list_check(
        cwd, day1, {:adapter => "gcov"},
        %w(bar/ foo/),
        [{ day1 => [3, 5] }, { day1 => [2, 2] }]
      )

      list_check(
        cwd, day1, {:adapter => "rbcov"},
        %w(foo/),
        [{ day1 => [4, 5] }]
      )

      list_check(
        cwd, day1, {:ext => "y"},
        %w(bar/),
        [{ day1 => [3, 5] }]
      )

      list_check(
        cwd, day1, {:incl => "foo/%"},
        %w(foo/),
        [{ day1 => [6, 7] }]
      )

      list_check(cwd, day1, {:incl => "foo/test1%"}, [], [])

      list_check(
        cwd, day1, {:excl => "foo/%"},
        %w(bar/),
        [{ day1 => [3, 5] }]
      )
    end

    should "return file list correctly" do
      list_check(
        Pathname("foo/"), day1, {},
        %w(test1.c test2.rb),
        [{ day1 => [2, 2] }, { day1 => [4, 5] }]
      )
    end

    should "return code correctly" do
      code_check(
        Pathname("foo/test1.c"), day1,
        [[1,   1, "int main() {"],
         [2,   1, "  foo();"],
         [3, nil, "}"]]
      )
    end

    should "return diff correctly" do
      code_check(
        Pathname("foo/test1.c"), day1, day1,
        [[1,   1, "int main() {",   1, "int main() {"],
         [2,   1, "  foo();"    ,   1, "  foo();"],
         [3, nil, "}"           , nil, "}"]]
      )
    end

    should "return changes correctly" do
      changes_check(
        3, :top, cwd, day1, {},
        [[:entry, day1, nil, 9, 12, :latest, :earliest]]
      )

      changes_check(
        3, :dir, Pathname("foo/"), day1, {},
        [[:entry, day1, nil, 6, 7, :latest, :earliest]]
      )

      changes_check(
        3, :file, Pathname("foo/test1.c"), day1, {},
        [[:entry, day1, nil, 2, 2, :latest, :earliest]]
      )
    end
  end

  day2 = day1.succ
  describe "2nd day: some changes (adding and modifying lines)" do
    should "fail to register older date" do
      ->{ Concov::Coverage.register(Date.parse("20081231"), ->{}) {}}
        .should.raise(Concov::ConcovError)
    end

    should "roll back when exception raised during source gathering" do
      -> { Concov::Coverage.register(day2, ->{}) { raise } }
        .should.raise(RuntimeError)

      Concov::Coverage.last_date.should == day1
    end

    should "success to register" do
      log = []
      prog = ->(*a) { log << a }
      Concov::Coverage.register(day2, prog) do |new_file|
        covs = {}

        #
        # test data 1: add two function calls
        #
        path = Pathname("foo/test1.c")
        file = new_file[path]
        file.puts "int main() {"
        file.puts "  foo();"
        file.puts "  bar();" # added
        file.puts "  baz();" # added
        file.puts "}"
        file.close
        covs[path] = ["gcov", [1, 1, 1, 1, nil]]

        #
        # test data 2: change a condition
        #
        path = Pathname("foo/test2.rb")
        file = new_file[path]
        file.puts "5.times do"
        file.puts "  p :foo"
        file.puts "end"
        file.puts "if true" # modified
        file.puts "  p :bar"
        file.puts "end"
        file.puts "p :end"
        file.close
        covs[path] = ["rbcov", [1, 5, nil, 1, 1, nil, 1]] # changed

        #
        # test data 3: no change
        #
        path = Pathname("bar/test3.y")
        file = new_file[path]
        file.puts "foo"
        file.puts "bar"
        file.puts "baz"
        file.puts "qux"
        file.puts "corge"
        file.puts "grault"
        file.close
        covs[path] = ["gcov", [1, 10, 0, nil, 100, 0]]

        covs
      end

      log.should == [
        ["gather source code", 1],
        ["gather source code", 2],
        ["gather source code", 3],
        ["register to database", 1, 3],
        ["register to database", 2, 3],
        ["register to database", 3, 3],
      ]
    end

    should "return history correctly" do
      range = day1..day2
      Concov::Coverage.history(:top, cwd, range, {})
        .should == { day1 => [9, 12], day2 => [12, 14] }

      Concov::Coverage.history(:dir, Pathname("foo/"), range, {})
        .should == { day1 => [6, 7], day2 => [9, 9] }

      Concov::Coverage.history(:file, Pathname("foo/test1.c"), range, {})
        .should == { day1 => [2, 2], day2 => [4, 4] }
    end

    should "return directory list correctly" do
      list_check(
        cwd, day1..day2, {},
        %w(bar/ foo/),
        [{ day1 => [3, 5], day2 => [3, 5] },
         { day1 => [6, 7], day2 => [9, 9] }]
      )
    end

    should "return diff correctly" do
      code_check(
        Pathname("foo/test1.c"), day1, day2,
        [[1,   1, "int main() {",   1, "int main() {"],
         [2,   1, "  foo();"    ,   1, "  foo();"    ],
         [3, nil, nil           ,   1, "  bar();"    ],
         [4, nil, nil           ,   1, "  baz();"    ],
         [5, nil, "}"           , nil, "}"           ]]
      )

      code_check(
        Pathname("foo/test2.rb"), day1, day2,
        [[  1,   1, "5.times do",   1, "5.times do"],
         [  2,   5, "  p :foo"  ,   5, "  p :foo"  ],
         [  3, nil, "end"       , nil, "end"       ],
         [nil,   1, "if false"  , nil, nil         ],
         [  4, nil, nil         ,   1, "if true"   ],
         [  5,   0, "  p :bar"  ,   1, "  p :bar"  ],
         [  6, nil, "end"       , nil, "end"       ],
         [  7,   1, "p :end"    ,   1, "p :end"    ]]
      )

      code_check(
        Pathname("bar/test3.y"), day1, day2,
        [[  1,   1, "foo"   ,   1, "foo"   ],
         [  2,  10, "bar"   ,  10, "bar"   ],
         [  3,   0, "baz"   ,   0, "baz"   ],
         [  4, nil, "qux"   , nil, "qux"   ],
         [  5, 100, "corge" , 100, "corge" ],
         [  6,   0, "grault",   0, "grault"]]
      )
    end

    should "return changes correctly" do
      changes_check(
        3, :top, cwd, day1, {},
        [[:entry, day2, nil, 12, 14, :latest],
         [:diff, day1, day2,
          { created: 0, deleted: 0, modified: 2, changed: 0,
            code_inc: 3, code_dec: 1, cov_inc: 4, cov_dec: 1 }],
         [:entry, day1, day2, 9, 12, :earliest]]
      )

      changes_check(
        3, :dir, Pathname("foo/"), day1, {},
        [[:entry, day2, nil, 9, 9, :latest],
         [:diff, day1, day2,
          { created: 0, deleted: 0, modified: 2, changed: 0,
            code_inc: 3, code_dec: 1, cov_inc: 4, cov_dec: 1 }],
         [:entry, day1, day2, 6, 7, :earliest]]
      )

      changes_check(
        3, :dir, Pathname("bar/"), day1, {},
        [[:entry, day1, nil, 3, 5, :latest, :earliest]]
      )

      changes_check(
        3, :file, Pathname("foo/test1.c"), day1, {},
        [[:entry, day2, nil, 4, 4, :latest],
         [:diff, day1, day2,
          { created: 0, deleted: 0, modified: 1, changed: 0,
            code_inc: 2, code_dec: 0, cov_inc: 2, cov_dec: 0 }],
         [:entry, day1, day2, 2, 2, :earliest]]
      )
    end
  end

  day3 = day2.succ
  describe "3rd day: some changes (changing and renaming files)" do
    should "success to register" do
      log = []
      prog = ->(*a) { log << a }
      Concov::Coverage.register(day3, prog) do |new_file|
        covs = {}

        #
        # test data 1: change covearge only
        #
        path = Pathname("foo/test1.c")
        file = new_file[path]
        file.puts "int main() {"
        file.puts "  foo();"
        file.puts "  bar();"
        file.puts "  baz();"
        file.puts "}"
        file.close
        covs[path] = ["gcov", [1, 1, 0, 0, nil]] # changed

        #
        # test data 2: file renamed (deleted and created)
        #
        path = Pathname("foo/test2-2.rb")
        file = new_file[path]
        file.puts "5.times do"
        file.puts "  p :foo"
        file.puts "end"
        file.puts "if true"
        file.puts "  p :bar"
        file.puts "end"
        file.puts "p :end"
        file.close
        covs[path] = ["rbcov", [1, 5, nil, 1, 1, nil, 1]]

        #
        # test data 3: no change
        #
        path = Pathname("bar/test3.y")
        file = new_file[path]
        file.puts "foo"
        file.puts "bar"
        file.puts "baz"
        file.puts "qux"
        file.puts "corge"
        file.puts "grault"
        file.close
        covs[path] = ["gcov", [1, 10, 0, nil, 100, 0]]

        covs
      end

      log.should == [
        ["gather source code", 1],
        ["gather source code", 2],
        ["gather source code", 3],
        ["register to database", 1, 3],
        ["register to database", 2, 3],
        ["register to database", 3, 3],
      ]
    end

    should "return history correctly" do
      range = day1..day3
      Concov::Coverage.history(:top, cwd, range, {})
        .should == {
          day1  => [9, 12],
          day2 => [12, 14],
          day3  => [10, 14],
        }
    end

    should "return diff correctly" do
      code_check(
        Pathname("foo/test1.c"), day2, day3,
        [[1,   1, "int main() {",   1, "int main() {"],
         [2,   1, "  foo();"    ,   1, "  foo();"    ],
         [3,   1, "  bar();"    ,   0, "  bar();"    ],
         [4,   1, "  baz();"    ,   0, "  baz();"    ],
         [5, nil, "}"           , nil, "}"           ]]
      )

      code_check(
        Pathname("foo/test2.rb"), day2, day3,
        [[nil,   1, "5.times do", nil, nil],
         [nil,   5, "  p :foo"  , nil, nil],
         [nil, nil, "end"       , nil, nil],
         [nil,   1, "if true"   , nil, nil],
         [nil,   1, "  p :bar"  , nil, nil],
         [nil, nil, "end"       , nil, nil],
         [nil,   1, "p :end"    , nil, nil]]
      )

      code_check(
        Pathname("foo/test2.rb"), day3, day2,
        [[1, nil, nil,   1, "5.times do"],
         [2, nil, nil,   5, "  p :foo"  ],
         [3, nil, nil, nil, "end"       ],
         [4, nil, nil,   1, "if true"   ],
         [5, nil, nil,   1, "  p :bar"  ],
         [6, nil, nil, nil, "end"       ],
         [7, nil, nil,   1, "p :end"    ]]
      )
    end

    should "return changes correctly" do
      changes_check(
        3, :top, cwd, day1, {},
        [[:entry, day3, nil, 10, 14, :latest],
         [:diff, day2, day3,
          { created: 1, deleted: 1, modified: 0, changed: 1,
            code_inc: 7, code_dec: 7, cov_inc: 5, cov_dec: 7 }],
         [:entry, day2, day3, 12, 14],
         [:diff, day1, day2,
          { created: 0, deleted: 0, modified: 2, changed: 0,
            code_inc: 3, code_dec: 1, cov_inc: 4, cov_dec: 1 }],
         [:entry, day1, day2, 9, 12, :earliest]]
      )

      changes_check(
        3, :file, Pathname("foo/test1.c"), day1, {},
        [[:entry, day3, nil, 2, 4, :latest],
         [:diff, day2, day3,
          { created: 0, deleted: 0, modified: 0, changed: 1,
            code_inc: 0, code_dec: 0, cov_inc: 0, cov_dec: 2 }],
         [:entry, day2, day3, 4, 4],
         [:diff, day1, day2,
          { created: 0, deleted: 0, modified: 1, changed: 0,
            code_inc: 2, code_dec: 0, cov_inc: 2, cov_dec: 0 }],
         [:entry, day1, day2, 2, 2, :earliest]]
      )

      changes_check(
        3, :dir, Pathname("bar/"), day1, {},
        [[:entry, day1, nil, 3, 5, :latest, :earliest]]
      )
    end
  end

  day4 = day3.succ
  describe "4th day: some changes (empty coverage and delete file)" do
    should "success to register (cancel empty file)" do
      log = []
      prog = ->(*a) { log << a }
      Concov::Coverage.register(day4, prog) do |new_file|
        covs = {}

        #
        # test data 1: change covearge only
        #
        path = Pathname("foo/test1.c")
        file = new_file[path]
        file.puts "int main() {"
        file.puts "  foo();"
        file.puts "  bar();"
        file.puts "  baz();"
        file.puts "}"
        file.close
        covs[path] = ["gcov", [nil, nil, nil, nil, nil]] # changed

        #
        # test data 2: no change
        #
        path = Pathname("foo/test2-2.rb")
        file = new_file[path]
        file.puts "5.times do"
        file.puts "  p :foo"
        file.puts "end"
        file.puts "if true"
        file.puts "  p :bar"
        file.puts "end"
        file.puts "p :end"
        file.close
        covs[path] = ["rbcov", [1, 5, nil, 1, 1, nil, 1]]

        #
        # test data 3: deleted
        #

        covs
      end

      log.should == [
        ["gather source code", 1],
        ["gather source code", 2],
        ["register to database", 1, 1],
      ]
    end

    should "return last_date correctly" do
      Concov::Coverage.last_date.should == day4
    end

    should "return directory list correctly" do
      list_check(
        cwd, day4, {},
        %w(foo/),
        [{ day4 => [5, 5] }]
      )
    end

    should "return diff correctly" do
      code_check(
        Pathname("foo/test2.rb"), day2, day4,
        [[nil,   1, "5.times do", nil, nil],
         [nil,   5, "  p :foo"  , nil, nil],
         [nil, nil, "end"       , nil, nil],
         [nil,   1, "if true"   , nil, nil],
         [nil,   1, "  p :bar"  , nil, nil],
         [nil, nil, "end"       , nil, nil],
         [nil,   1, "p :end"    , nil, nil]]
      )

      code_check(Pathname("foo/test2.rb"), day3, day4, [])
    end
  end

  day5 = day4.succ
  describe "5th day: empty tree" do
    should "success to register" do
      log = []
      prog = ->(*a) { log << a }
      Concov::Coverage.register(day5, prog) do |new_file|
        {}
      end

      log.should == [
        ["warning: nothing to register found; empty tree will be registered"],
      ]
    end

    should "not change last_date" do
      Concov::Coverage.last_date.should == day4
    end

    should "return directory list correctly" do
      list_check(cwd, day5, {}, [], [])
    end
  end

  day6 = day5.succ
  describe "6th day: empty tree again" do
    should "success to register" do
      log = []
      prog = ->(*a) { log << a }
      Concov::Coverage.register(day6, prog) do |new_file|
        {}
      end

      log.should == [
        ["warning: nothing to register found; empty tree will be registered"],
      ]
    end

    should "not change last_date" do
      Concov::Coverage.last_date.should == day4
    end

    should "return directory list correctly" do
      list_check(cwd, day6, {}, [], [])
    end
  end

  day7 = day6.succ
  describe "7th day: skip registration" do
    should "not change last_date" do
      Concov::Coverage.last_date.should == day4
    end

    should "return directory list correctly" do
      list_check(cwd, day7, {}, [], [])
    end
  end

  day8 = day7.succ
  describe "8th day: recovering tree" do
    should "success to register" do
      log = []
      prog = ->(*a) { log << a }
      Concov::Coverage.register(day8, prog) do |new_file|
        covs = {}

        #
        # test data 3: recover
        #
        path = Pathname("bar/test3.y")
        file = new_file[path]
        file.puts "foo"
        file.puts "bar"
        file.puts "baz"
        file.puts "qux"
        file.puts "corge"
        file.puts "grault"
        file.close
        covs[path] = ["gcov", [1, 10, 0, nil, 100, 0]]

        covs
      end

      log.should == [
        ["gather source code", 1],
        ["register to database", 1, 1],
      ]
    end

    should "return last_date correctly" do
      Concov::Coverage.last_date.should == day8
    end

    should "return directory list correctly" do
      list_check(
        cwd, day8, {},
        %w(bar/),
        [{ day8 => [3, 5] }]
      )
    end
  end

  day9 = day8.succ
  describe "9th day: no change" do
    should "success to register" do
      log = []
      prog = ->(*a) { log << a }
      Concov::Coverage.register(day9, prog) do |new_file|
        covs = {}

        #
        # test data 3: no change
        #
        path = Pathname("bar/test3.y")
        file = new_file[path]
        file.puts "foo"
        file.puts "bar"
        file.puts "baz"
        file.puts "qux"
        file.puts "corge"
        file.puts "grault"
        file.close
        covs[path] = ["gcov", [1, 10, 0, nil, 100, 0]]

        covs
      end

      log.should == [
        ["gather source code", 1],
        ["register to database", 1, 1],
      ]
    end

    should "return last_date correctly" do
      Concov::Coverage.last_date.should == day9
    end

    should "return directory list correctly" do
      list_check(
        cwd, day9, {},
        %w(bar/),
        [{ day9 => [3, 5] }]
      )
    end
  end

  dayA = day9.succ
  dayB = dayA.succ
  describe "11th day: skip 10th" do
    should "success to register" do
      log = []
      prog = ->(*a) { log << a }
      Concov::Coverage.register(dayB, prog) do |new_file|
        covs = {}

        #
        # test data 3: no change
        #
        path = Pathname("bar/test3.y")
        file = new_file[path]
        file.puts "foo"
        file.puts "bar"
        file.puts "baz"
        file.puts "qux"
        file.puts "corge"
        file.puts "grault"
        file.close
        covs[path] = ["gcov", [1, 10, 0, nil, 100, 0]]

        covs
      end

      log.should == [
        ["gather source code", 1],
        ["register to database", 1, 1],
      ]
    end

    should "return last_date correctly" do
      Concov::Coverage.last_date.should == dayB
    end

    should "return directory list correctly" do
      list_check(
        cwd, dayB, {},
        %w(bar/),
        [{ dayB => [3, 5] }]
      )
    end
  end

  describe "week-term test" do
    #
    # day:                 1      2      3      4    5-7     8    9    A     B
    #
    # - foo/test1.c    C-> * -M-> * -C-> * -D
    # - foo/test2.rb   C-> * -M-> * -D
    # - foo/test2-2.rb               C-> * ---> E -D
    # - bar/test3.y    C-> * ---> * ---> * -D            C-> * -> * -D   C-> *
    #
    # hit:                 9     12     10      5            3    3          3
    # found:              12     14     14      5            5    5          5
    #
    should "return weekly list correctly" do
      list_check(
        cwd, day1..day7, {},
        %w(bar/ foo/),
        [{ day1 => [3, 5], day2 => [3, 5], day3 => [3, 5]                 },
         { day1 => [6, 7], day2 => [9, 9], day3 => [7, 9], day4 => [5, 5] }]
      )

      list_check(
        cwd, day3..day9, {},
        %w(bar/ foo/),
        [{ day3 => [3, 5],                 day8 => [3, 5], day9 => [3, 5] },
         { day3 => [7, 9], day4 => [5, 5]                                 }]
      )
    end

    should "return history correctly" do
      range = day1..day9
      Concov::Coverage.history(:top, cwd, range, {})
        .should == {
          day1 => [ 9, 12],
          day2 => [12, 14],
          day3 => [10, 14],
          day4 => [ 5,  5],
          day8 => [ 3,  5],
          day9 => [ 3,  5],
        }
    end

    # all changes:
    #
    #   B-latest
    #    | C AdB
    #    A
    #    | D 9dA
    #   8-9
    #    | C 5d8
    #   5-7
    #    | D 4d5
    #    4
    #    | DD 3d4
    #    3
    #    | CCD 2d3
    #    2
    #    | MM 1d2
    #    1
    #
    expect =
      [[:entry, dayB, nil, 3, 5, :latest],
       [:diff, dayA, dayB,
        { created: 1, deleted: 0, modified: 0, changed: 0,
          code_inc: 6, code_dec: 0, cov_inc: 3, cov_dec: 0 }],
       [:entry, dayA, dayB, 0, 0],
       [:diff, day8, dayA,
        { created: 0, deleted: 1, modified: 0, changed: 0,
          code_inc: 0, code_dec: 6, cov_inc: 0, cov_dec: 3 }],
       [:entry, day8, dayA, 3, 5],
       [:diff, day5, day8,
        { created: 1, deleted: 0, modified: 0, changed: 0,
          code_inc: 6, code_dec: 0, cov_inc: 3, cov_dec: 0 }],
       [:entry, day5, day8, 0, 0],
       [:diff, day4, day5,
        { created: 0, deleted: 1, modified: 0, changed: 0,
          code_inc: 0, code_dec: 7, cov_inc: 0, cov_dec: 5 }],
       [:entry, day4, day5, 5, 5],
       [:diff, day3, day4,
        { created: 0, deleted: 2, modified: 0, changed: 0,
          code_inc: 0, code_dec: 11, cov_inc: 0, cov_dec: 5 }],
       [:entry, day3, day4, 10, 14],
       [:diff, day2, day3,
        { created: 1, deleted: 1, modified: 0, changed: 1,
          code_inc: 7, code_dec: 7, cov_inc: 5, cov_dec: 7 }],
       [:entry, day2, day3, 12, 14],
       [:diff, day1, day2,
        { created: 0, deleted: 0, modified: 2, changed: 0,
          code_inc: 3, code_dec: 1, cov_inc: 4, cov_dec: 1 }],
       [:entry, day1, day2, 9, 12, :earliest],
      ]

    day0 = Date.parse("20081231")
    dayC = dayB.succ

    should "return changes with window size 1" do
      exp1 = [[:navi, :newer, day4]] + expect[10, 5]
      exp2 = [[:navi, :newer, day5]] + expect[ 8, 5] + [[:navi, :older, day1]]
      exp3 = [[:navi, :newer, day8]] + expect[ 6, 5] + [[:navi, :older, day2]]
      exp4 = [[:navi, :newer, dayA]] + expect[ 4, 5] + [[:navi, :older, day3]]
      exp5 = [[:navi, :newer, dayB]] + expect[ 2, 5] + [[:navi, :older, day4]]
      exp6 =                           expect[ 0, 5] + [[:navi, :older, day5]]
      changes_check(1, :top, cwd, day0, {}, exp1.dup)
      changes_check(1, :top, cwd, day1, {}, exp1.dup)
      changes_check(1, :top, cwd, day2, {}, exp1.dup)
      changes_check(1, :top, cwd, day3, {}, exp2.dup)
      changes_check(1, :top, cwd, day4, {}, exp3.dup)
      changes_check(1, :top, cwd, day5, {}, exp4.dup)
      changes_check(1, :top, cwd, day6, {}, exp4.dup)
      changes_check(1, :top, cwd, day7, {}, exp4.dup)
      changes_check(1, :top, cwd, day8, {}, exp5.dup)
      changes_check(1, :top, cwd, day9, {}, exp5.dup)
      changes_check(1, :top, cwd, dayA, {}, exp6.dup)
      changes_check(1, :top, cwd, dayB, {}, exp6.dup)
      changes_check(1, :top, cwd, dayC, {}, exp6.dup)
    end

    should "return changes with window size 2" do
      exp1 = [[:navi, :newer, dayA]] + expect[6, 9]
      exp2 = [[:navi, :newer, dayB]] + expect[4, 9] + [[:navi, :older, day1]]
      exp3 = [[:navi, :newer, dayB]] + expect[2, 9] + [[:navi, :older, day1]]
      exp4 =                           expect[0, 9] + [[:navi, :older, day2]]
      changes_check(2, :top, cwd, day0, {}, exp1.dup)
      changes_check(2, :top, cwd, day1, {}, exp1.dup)
      changes_check(2, :top, cwd, day2, {}, exp1.dup)
      changes_check(2, :top, cwd, day3, {}, exp1.dup)
      changes_check(2, :top, cwd, day4, {}, exp2.dup)
      changes_check(2, :top, cwd, day5, {}, exp3.dup)
      changes_check(2, :top, cwd, day6, {}, exp3.dup)
      changes_check(2, :top, cwd, day7, {}, exp3.dup)
      changes_check(2, :top, cwd, day8, {}, exp4.dup)
      changes_check(2, :top, cwd, day9, {}, exp4.dup)
      changes_check(2, :top, cwd, dayA, {}, exp4.dup)
      changes_check(2, :top, cwd, dayB, {}, exp4.dup)
      changes_check(2, :top, cwd, dayC, {}, exp4.dup)
    end

    should "return changes with window size 3" do
      exp1 = [[:navi, :newer, dayB]] + expect[2, 13]
      exp2 =                           expect[0, 13] + [[:navi, :older, day1]]
      changes_check(3, :top, cwd, day0, {}, exp1.dup)
      changes_check(3, :top, cwd, day1, {}, exp1.dup)
      changes_check(3, :top, cwd, day2, {}, exp1.dup)
      changes_check(3, :top, cwd, day3, {}, exp1.dup)
      changes_check(3, :top, cwd, day4, {}, exp1.dup)
      changes_check(3, :top, cwd, day5, {}, exp2.dup)
      changes_check(3, :top, cwd, day6, {}, exp2.dup)
      changes_check(3, :top, cwd, day7, {}, exp2.dup)
      changes_check(3, :top, cwd, day8, {}, exp2.dup)
      changes_check(3, :top, cwd, day9, {}, exp2.dup)
      changes_check(3, :top, cwd, dayA, {}, exp2.dup)
      changes_check(3, :top, cwd, dayB, {}, exp2.dup)
      changes_check(3, :top, cwd, dayC, {}, exp2.dup)
    end

    should "return changes with other window sizes" do
      (day1..dayC).each {|d| changes_check(4, :top, cwd, d, {}, expect.dup) }
      (day1..dayC).each {|d| changes_check(5, :top, cwd, d, {}, expect.dup) }
      (day1..dayC).each {|d| changes_check(6, :top, cwd, d, {}, expect.dup) }
    end
  end
end
