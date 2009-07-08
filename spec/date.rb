#
# concov - continuous coverage manager
#
#   * spec/date.rb: date spec
#

require "ramaze"
require "ramaze/spec/bacon"

require "lib/date"

describe Concov::DateInstanceExt, Concov::DateClassExt do
  should "convert into show" do
    Date.parse("20090101").to_show.should == "2009/01/01"
  end

  should "convert from show str" do
    Date.from_show("2009/01/01").should == Date.parse("20090101")
    ->{ Date.from_show("foo") }.should.raise(Concov::ConcovError)
  end

  should "format date until date" do
    Date.parse("20090101").to_show_until(Date.parse("20090101"))
      .should == "2009/01/01"

    Date.parse("20090101").to_show_until(Date.parse("20090102"))
      .should == "2009/01/01 - 02"

    Date.parse("20090101").to_show_until(Date.parse("20090201"))
      .should == "2009/01/01 - 02/01"

    Date.parse("20090101").to_show_until(Date.parse("20100101"))
      .should == "2009/01/01 - 2010/01/01"
  end

  should "convert into path" do
    Date.parse("20090101").to_path.should == "20090101"
  end

  should "convert from path str" do
    Date.from_path("20090101").should == Date.parse("20090101")
    ->{ Date.from_path("foo") }.should.raise(Concov::ConcovError)
  end
end
