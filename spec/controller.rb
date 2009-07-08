#
# concov - continuous coverage manager
#
#   * spec/controller.rb: controller spec
#

require "ramaze"
require "ramaze/spec/bacon"
require "nokogiri"
require "tmpdir"

require "spec/helper"

require "lib/config"
require "lib/error"
require "model/coverage"
require "controller/main"
require "lib/command"
require "lib/command/init"
require "lib/command/info"
require "lib/command/register"
require "lib/command/view"

require "rbconfig"

# load configuration file of sandbox
sandbox_base_path, sandbox_conf_path = setup_sandbox
Dir.chdir(sandbox_base_path)
Concov::Config.deploy(sandbox_conf_path)

# ramaze setup
Ramaze.options.roots = [File.dirname(__DIR__)]

describe Concov::MainController do
  behaves_like :rack_test

  def check(path)
    get(path).status.should == 200
    last_response["Content-Type"].should == "text/html"
    Nokogiri(last_response.body)
  end

  should "report error when database not is initialized" do
    check("/").search("h1").text.should ==
      "concov error: database is not initialized"
  end

  should "report error when no data is found" do
    run_concov("init")
    check("/").search("h1").text.should ==
      "concov error: no data found; please register first"
  end

  run_concov("register", "-d", "20090101", sample_env("20090101"))

  should "handle list view correctly" do
    html = check("/")
    html.search("h1").text.should == ""
    names = html.search("table.list td.name")
    names.count.should == 3
    names[0].text.strip.should == "bar/"
    names[1].text.strip.should == "foo/"
    names[2].text.strip.should == "(total)"

    html = check("/20090101/foo/")
    html.search("h1").text.should == ""
    names = html.search("table.list td.name")
    names.count.should == 3
    names[0].text.strip.should == "test1.c"
    names[1].text.strip.should == "test2.rb"
    names[2].text.strip.should == "(total)"

    html = check("/20090101/bar/")
    html.search("h1").text.should == ""
    names = html.search("table.list td.name")
    names.count.should == 2
    names[0].text.strip.should == "test3.y"
    names[1].text.strip.should == "(total)"

    html = check("/w20090101/")
    html.search("h1").text.should == ""
    names = html.search("table.list td.name")
    names.count.should == 3
    names[0].text.strip.should == "bar/"
    names[1].text.strip.should == "foo/"
    names[2].text.strip.should == "(total)"
  end

  should "handle code view correctly" do
    html = check("/20090101/foo/test1.c")
    html.search("h1").text.should == ""
    html.search("table.code td.lineno").count.should == 3

    html = check("/20090101/foo/test2.rb")
    html.search("h1").text.should == ""
    html.search("table.code td.lineno").count.should == 7
  end

  should "handle changes view correctly" do
    html = check("/c20090101/foo/test1.c")
    html.search("h1").text.should == ""
    entries = html.search("table.changes td.entry")
    entries.count.should == 1
  end

  should "handle chart view correctly" do
    html = check("/g20090101/foo/test1.c")
    html.search("h1").text.should == ""
  end

  run_concov("register", "-d", "20090102", sample_env("20090102"))

  should "handle diff view correctly" do
    html = check("/d20090102/")
    html.search("h1").text.should == ""

    html = check("/d20090102/foo/test1.c")
    html.search("h1").text.should == ""
  end

  should "handle changes view correctly" do
    html = check("/c20090101/foo/test1.c")
    html.search("h1").text.should == ""
    entries = html.search("table.changes td.entry")
    entries.count.should == 2
  end
  # test, test, test...
end
